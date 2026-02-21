# Architecture — Git-Sync

> Deep-dive technical reference for the internal design of Git-Sync. Covers every subsystem, the reasoning behind each design decision, and the exact interface contract between components.

---

## System Overview

Git-Sync is a single-file Bash application. There are no imports, no external libraries, and no compiled components. Every subsystem is a Bash function. The program runs as a single process with one temporary background subprocess (the spinner) that lives only for the duration of an async git operation.

```
┌─────────────────────────────────────────────────────────┐
│                     git-sync.sh                         │
│                                                         │
│  Global Scope                                           │
│  ├── Color/Theme variables                              │
│  ├── SPINNER_PID=""                                     │
│  ├── spinner_frames array                               │
│  ├── MENU_ITEMS array                                   │
│  └── MENU_COUNT                                         │
│                                                         │
│  Function Scope                                         │
│  ├── menu()              ← main loop, owns: selected    │
│  │   ├── draw_menu()                                    │
│  │   └── read_key()                                     │
│  ├── initializer_helper()                               │
│  │   ├── gitignore_creator_helper()                     │
│  │   └── get_commit_message()                           │
│  └── push_helper()                                      │
│                                                         │
│  Utility Layer                                          │
│  ├── print_success/error/info/warn/step/callback        │
│  ├── section_header / hr / print_blank                  │
│  ├── draw_banner                                        │
│  ├── start_spinner / stop_spinner                       │
│  └── clear_screen / hide_cursor / show_cursor           │
└─────────────────────────────────────────────────────────┘
```

---

## Subsystem: Color & Theme

All color values are stored as global string variables containing raw ANSI escape codes. They are interpolated directly into `echo -e` and `printf` strings throughout the codebase.

```
Semantic aliases:
  ACCENT  = BOLD + GREEN        → success states, staged file markers
  MUTED   = DIM  + WHITE        → hints, secondary text, hr rules
  DANGER  = BOLD + RED          → error messages
  INFO    = BOLD + CYAN         → informational messages
  WARN    = BOLD + YELLOW       → non-fatal warnings

Background blocks:
  BG_HIGHLIGHT = \033[48;5;22m  → dark green  → success callback banners
  BG_WARN      = \033[48;5;52m  → dark red    → warning callback banners
  BG_ERROR     = \033[48;5;88m  → deep red    → error callback banners
  BG_PANEL     = \033[48;5;17m  → dark navy   → Push to Remote menu row
```

---

## Subsystem: Spinner

The spinner is the only place in Git-Sync where a child process is deliberately created and kept alive.

**Start:** A subshell `( while true; do ... done ) &` runs the animation loop. The PID is stored in global `SPINNER_PID`.

**Stop:** `kill $SPINNER_PID` terminates the subshell. `wait $SPINNER_PID` reaps it so it does not become a zombie. `printf "\r\033[2K"` clears the spinner line.

**Why a subshell:** Git operations (`git init`, `git add`, `git commit`, `git push`) are synchronous and block the main process. The only way to animate while they run is to fork the animation into a background child.

**Why `SPINNER_PID` is global:** The spinner is started in one function scope and stopped in the same or a calling function. A global is the only way to pass the PID across function boundaries in Bash without a file or pipe.

---

## Subsystem: Key Reader

```
Byte sequence emitted by terminal for each input:

  Enter key    →  0x0A  (newline, read as empty string by -rsn1)
  ESC key      →  0x1B  (single byte, nothing follows within 1s)
  Up arrow     →  0x1B  0x5B  0x41   (\x1b  [  A)
  Down arrow   →  0x1B  0x5B  0x42   (\x1b  [  B)
  Letter "q"   →  0x71
  Letter "1"   →  0x31
```

**Why byte-by-byte instead of `-rsn2 -t 0.05`:**
macOS ships bash 3.2 (2007). In bash 3.2, the `-t` flag on `read` only accepts integer seconds. A value of `0.05` is silently rejected and the read returns immediately with an empty result. The previous implementation used `-rsn2 -t 0.05` which read two bytes with a 50ms timeout — on macOS this always returned empty, making `seq` always empty, making every arrow key look like a bare ESC, triggering the exit branch.

The fix reads one byte at a time with `-t 1` (integer, universally supported). Since the terminal emits all three bytes of an arrow key atomically and instantly, the 1-second timeout is never actually waited on in practice.

**Decision tree inside `read_key`:**

```
read b0 (blocking, no timeout)
  │
  ├── b0 == 0x1B?
  │     │
  │     ├── read b1 (timeout 1s)
  │     │     │
  │     │     ├── b1 empty?  → "ESC"
  │     │     │
  │     │     └── b1 == "["?
  │     │           │
  │     │           ├── read b2 (timeout 1s)
  │     │           │     ├── b2 == "A" → "UP"
  │     │           │     ├── b2 == "B" → "DOWN"
  │     │           │     └── *         → "SEQ:[b2"
  │     │           │
  │     │           └── b1 != "["  → "SEQ:b1"
  │     │
  ├── b0 == ""  → "ENTER"
  ├── b0 == "q"/"Q" → "QUIT"
  ├── b0 == "1"  → "1"
  ├── b0 == "3"  → "3"
  └── *          → "OTHER:b0"
```

---

## Subsystem: Menu Navigation

The menu is a **state machine** with one integer state variable: `selected`.

```
State:    selected ∈ {0, 1, 2}
Events:   UP, DOWN, ENTER, "1", "3", ESC, QUIT
```

**Transitions:**

```
UP   → selected = (selected - 1 + MENU_COUNT) mod MENU_COUNT
DOWN → selected = (selected + 1) mod MENU_COUNT

ENTER on 0 → initializer_helper()
ENTER on 1 → push_helper()
ENTER on 2 → exit

"1"  → initializer_helper()   (bypasses selected state)
"3"  → push_helper()          (bypasses selected state)

ESC / QUIT → exit
```

**Why `draw_menu` takes `selected` as parameter rather than reading the global:**
This makes the renderer a pure function of its input. It does not read any state it does not receive. The loop can call `draw_menu "$selected"` and the rendering is deterministic.

**Why each row has a hardcoded color rather than a color array:**
Bash arrays of ANSI escape strings with embedded backslashes are unreliable across bash versions. The three `if [[ "$i" -eq N ]]` branches are explicit and transparent.

---

## Subsystem: `initializer_helper`

This function orchestrates the complete commit workflow. It returns early at multiple points using pre-condition checks (guard clauses) rather than deeply nested `if` blocks.

**Guard clause order:**
1. `f_counter == 0` → no files → return
2. `staged_check` empty → nothing new → return
3. `commit_status != 0` → commit failed → no early return, just callback, then fall through to cleanup

**Why `git diff --cached --name-only` after `git add`:**
`git add .` will succeed even when no files have changed since the last commit (it updates the index to match the working tree, which is a no-op for unchanged files). Without the diff check, `git commit` would be called and would print "nothing to commit" to stderr, which we suppress with `> /dev/null 2>&1`. The diff check lets us surface this as a styled callback before wasting a git invocation.

**Why `$?` must be captured immediately:**
`stop_spinner` calls `kill`, `wait`, and `printf`. Any of these resets `$?` to their own exit codes. Capturing `local commit_status=$?` on the line immediately after `git commit` preserves the correct value.

---

## Subsystem: `push_helper`

Four sequential gates. Each gate either allows the function to continue or fires a callback and returns early.

```
Gate 1 — repo exists       → [ ! -d ".git" ]
Gate 2 — remote exists     → git remote | empty check
Gate 3 — commits exist     → git rev-parse HEAD
Gate 4 — branch not behind → git status --porcelain=v1 --branch | grep "^##"
```

**Why four gates instead of one compound check:**
Each gate produces a different callback with a different recovery hint. A compound check would only allow one generic error message. Separate gates give the user exact, actionable feedback.

**Why `git status --porcelain=v1 --branch` for ahead/behind:**
This is the most portable way to get branch tracking information. `git log origin/branch..HEAD --oneline` requires the tracking reference to exist. `git rev-list --count` has similar requirements. `--porcelain=v1 --branch` works even when tracking is not configured, producing `## branch` with no `ahead/behind` markers, which falls into the `else` branch safely.

**Why `sed` instead of `grep -oP`:**
`grep -oP` uses Perl-compatible regex. BSD grep (macOS) does not support it. `sed 's/.*ahead \([0-9]*\).*/\1/'` uses BRE (Basic Regular Expressions) which is supported by every `sed` implementation.

---

## Subsystem: `print_callback`

```bash
print_callback() {
    local icon="$1"    # visual symbol: ◎  ✘
    local msg="$2"     # user-facing message string
    local bg="$3"      # ANSI background escape variable
    local fg="$4"      # ANSI foreground escape variable
    print_blank
    echo -e "  ${bg}${fg}${BOLD}  ${icon}  ${msg}  ${RESET}"
    print_blank
}
```

**Design rationale:** All eight error/warning states in the application needed a consistent visual language. Rather than eight separate `echo` calls with different inline colors, a single parameterized function ensures that changing the layout of a callback block (padding, icon position, reset placement) requires editing exactly one line.

---

## Data Flow Summary

```
User keystroke
    │
    ▼
read_key() → normalized string token
    │
    ▼
menu() case dispatch
    │
    ├──▶ draw_menu(selected)       [read-only, renders UI]
    │
    ├──▶ initializer_helper()
    │       │
    │       ├── git init (conditional)
    │       ├── gitignore_creator_helper()
    │       ├── file glob → real_files[]
    │       ├── git add (conditional on f_counter)
    │       ├── git diff --cached (staged check)
    │       ├── get_commit_message() → via /dev/tty
    │       └── git commit -m
    │
    └──▶ push_helper()
            │
            ├── .git check (gate 1)
            ├── git remote check (gate 2)
            ├── git rev-parse HEAD (gate 3)
            ├── git status --branch (gate 4)
            └── git push origin branch
```

---

## Threading Model

Git-Sync is single-threaded except during spinner animation. The threading model is:

```
Main process (PID N)
    │  blocks on git operations
    │  manages all I/O and state
    │
    └── Spinner subprocess (PID N+1)
            │  runs only between start_spinner() and stop_spinner()
            │  writes only to stdout (animated line)
            └── killed by SIGTERM from main process
```

No race conditions exist because the spinner only writes and never reads state. The main process never writes to stdout while the spinner is alive (it waits for git to complete). The only shared resource is stdout, and by convention they do not overlap.

---

## Cross-Platform Compatibility

| Feature | macOS bash 3.2 | Linux bash 5+ | Notes |
|---|---|---|---|
| `read -t 0.05` fractional timeout | ❌ Silently fails | ✅ Supported | Fixed by using `-t 1` integer |
| `grep -oP` Perl regex | ❌ Not supported | ✅ Supported | Fixed by using `sed` BRE |
| `read -rsn1` single byte read | ✅ Supported | ✅ Supported | Core of read_key |
| `printf '%*s'` padding | ✅ Supported | ✅ Supported | Used in section_header |
| `(( arithmetic ))` | ✅ Supported | ✅ Supported | Used in nav mod math |
| ANSI 256-color codes | ✅ Most terminals | ✅ All terminals | Requires 256-color terminal |
| `tput cols` terminal width | ✅ Supported | ✅ Supported | Falls back to 60 |
