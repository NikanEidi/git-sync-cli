# Traceability Matrix — Git-Sync

> Maps every user requirement to its implementing function, the specific lines of code, the test condition, and the expected output. Use this document to verify that no requirement is unimplemented and no code block is orphaned.

---

## Requirement Categories

| ID Prefix | Category |
|---|---|
| `UI-` | User Interface & Visual Design |
| `NAV-` | Navigation & Keyboard Input |
| `GIT-` | Git Operations |
| `CB-` | Callback & State Feedback |
| `SYS-` | System & Shell Integration |
| `PUSH-` | Push to Remote |

---

## Full Traceability Matrix

| Req ID | Requirement | Implementing Function | Code Section | Verification Condition | Expected Output |
|---|---|---|---|---|---|
| UI-01 | Display neon-purple ASCII art banner on every screen | `draw_banner()` | `# BANNER` | Run script, observe every screen transition | 5-line `██` art in `\033[38;5;171m` with subtitle and rules |
| UI-02 | Render box-drawn section headers centered in 44-char frame | `section_header()` | `# STYLED OUTPUT HELPERS` | Call `section_header "Git Sync"` | `┌────┐ │ Git Sync │ └────┘` centered correctly |
| UI-03 | Render full-width horizontal rules with configurable char | `hr()` | `# STYLED OUTPUT HELPERS` | Call `hr "·"` and `hr "─"` | Lines spanning terminal width in correct char |
| UI-04 | Show styled status icons for success, error, info, warn, step | `print_success/error/info/warn/step()` | `# STYLED OUTPUT HELPERS` | Trigger each branch | `✔` green / `✘` red / `ℹ` cyan / `⚠` yellow / `›` magenta |
| UI-05 | Highlight active menu row with `❯` arrow and colored background | `draw_menu()` | `# MENU RENDERER` | Navigate with arrow keys | Active row shows `❯` with unique BG color per row |
| UI-06 | Dim inactive menu rows visually | `draw_menu()` | `# MENU RENDERER` | Navigate, observe non-selected rows | Rows without focus render in `${DIM}` |
| UI-07 | Show commit confirmation banner on successful commit | `initializer_helper()` | `# GIT PROCESS HELPER` | Commit a real change | `${BG_HIGHLIGHT}` green banner: `✔ Committed: "msg"` |
| UI-08 | Show push confirmation banner on successful push | `push_helper()` | `# PUSH TO REMOTE HELPER` | Push a commit to remote | `${BG_HIGHLIGHT}` banner: `✔ Successfully pushed to origin/branch` |
| UI-09 | Restore terminal cursor unconditionally on any exit | `trap` | `# TERMINAL UTILS` | Press Ctrl+C mid-operation | Cursor visible, `tput cnorm` called |
| UI-10 | Hide cursor during all menu states | `hide_cursor()` in `menu()` | `# MENU LOOP` | Observe menu screen | No blinking cursor visible |
| NAV-01 | Arrow up key moves selection upward | `read_key()` → `UP` → `menu()` | `# KEY READER` + `# MENU LOOP` | Press `↑` on any row | `selected` decrements with wraparound |
| NAV-02 | Arrow down key moves selection downward | `read_key()` → `DOWN` → `menu()` | `# KEY READER` + `# MENU LOOP` | Press `↓` on any row | `selected` increments with wraparound |
| NAV-03 | Wraparound — up from row 0 goes to last row | `menu()` mod arithmetic | `# MENU LOOP` | Press `↑` on row 0 | `selected` becomes `MENU_COUNT - 1` |
| NAV-04 | Wraparound — down from last row goes to row 0 | `menu()` mod arithmetic | `# MENU LOOP` | Press `↓` on last row | `selected` becomes 0 |
| NAV-05 | Enter key confirms currently highlighted row | `read_key()` → `ENTER` → `case $selected` | `# MENU LOOP` | Highlight row 1, press Enter | `push_helper()` called |
| NAV-06 | Key `1` directly triggers Git-Sync regardless of selection | `menu()` case `1` | `# MENU LOOP` | Press `1` from any selection | `initializer_helper()` called immediately |
| NAV-07 | Key `3` directly triggers Push to Remote regardless of selection | `menu()` case `3` | `# MENU LOOP` | Press `3` from any selection | `push_helper()` called immediately |
| NAV-08 | ESC key exits the program | `read_key()` → `ESC` → `menu()` | `# KEY READER` + `# MENU LOOP` | Press `Esc` | Goodbye banner shown, script exits |
| NAV-09 | Q / q key exits the program | `read_key()` → `QUIT` → `menu()` | `# KEY READER` + `# MENU LOOP` | Press `q` | Goodbye banner shown, script exits |
| NAV-10 | Arrow key bytes read individually — macOS bash 3.2 safe | `read_key()` byte-by-byte reads | `# KEY READER` | Run on macOS, press `↑` `↓` | No false ESC trigger; UP/DOWN returned correctly |
| NAV-11 | Bare ESC distinguishable from arrow key sequences | `read_key()` — `b1` timeout check | `# KEY READER` | Press bare `Esc` vs press `↑` | `ESC` vs `UP` returned correctly in both cases |
| GIT-01 | Detect existing `.git` directory and skip `git init` | `initializer_helper()` | `# GIT PROCESS HELPER` | Run in repo dir | `checker = -1`, prints "already initialized" |
| GIT-02 | Run `git init` when no `.git` directory exists | `initializer_helper()` | `# GIT PROCESS HELPER` | Run in empty dir | `git init` executes, `checker = 0` |
| GIT-03 | Glob hidden files including dotfiles, exclude `.` `..` `.git` | `for f in .[!.]* *` loop | `# GIT PROCESS HELPER` | Dir with `.gitignore` and `main.py` | Both files appear in `real_files`, `.git` excluded |
| GIT-04 | Stage single file when `f_counter == 1` | `initializer_helper()` | `# GIT PROCESS HELPER` | Directory with exactly 1 file | `git add "${real_files[0]}"` called |
| GIT-05 | Stage all files when `f_counter > 1` | `initializer_helper()` | `# GIT PROCESS HELPER` | Directory with multiple files | `git add .` called |
| GIT-06 | Show tree or fallback file list before staging | `tree` or `printf` fallback | `# GIT PROCESS HELPER` | Multiple files present | File list rendered in neon purple before staging |
| GIT-07 | Check staged diff before prompting for commit message | `git diff --cached --name-only` | `# GIT PROCESS HELPER` | Re-run after clean commit | Staged check returns empty, callback fires |
| GIT-08 | Display list of staged files before commit prompt | `echo "$staged_check"` loop | `# GIT PROCESS HELPER` | Stage new changes | Each staged file shown with `+` prefix |
| GIT-09 | Capture commit exit code immediately after `git commit` | `local commit_status=$?` | `# GIT PROCESS HELPER` | Force a commit failure | Non-zero exit captured before `stop_spinner` |
| GIT-10 | Create `.gitignore` on first init only | `gitignore_creator_helper()` | `# GITIGNORE CREATOR` | Run in new dir, then re-run | Created first time, warned-skipped second time |
| GIT-11 | Capture commit message safely via `/dev/tty` | `get_commit_message()` | `# COMMIT MESSAGE INPUT` | Run Git-Sync, type message | Message visible in terminal, captured correctly despite subshell |
| GIT-12 | Default commit message when input is blank | `${msg:-Automatic sync commit}` | `# COMMIT MESSAGE INPUT` | Press Enter with no message | Commit message is "Automatic sync commit" |
| CB-01 | Callback when directory has no files | `print_callback` in `initializer_helper` | `# GIT PROCESS HELPER` | Run in empty directory | Yellow BG: `◎ No files found in this directory` |
| CB-02 | Callback when nothing is staged after `git add` | `print_callback` in `initializer_helper` | `# GIT PROCESS HELPER` | Run with no changes since last commit | Yellow BG: `◎ Nothing to commit. Your repo is already up to date` |
| CB-03 | Callback when `git commit` fails | `print_callback` in `initializer_helper` | `# GIT PROCESS HELPER` | Corrupt git state or no user config | Red BG: `✘ Commit failed. Check your git config` |
| CB-04 | Callback when `.git` missing during push | `print_callback` in `push_helper` | `# PUSH TO REMOTE HELPER` | Press `3` in non-repo directory | Red BG: `✘ No git repository found` |
| CB-05 | Callback when no remote configured | `print_callback` in `push_helper` | `# PUSH TO REMOTE HELPER` | Repo with no remote set | Yellow BG: `◎ No remote origin configured` with `git remote add` hint |
| CB-06 | Callback when no commits exist before push | `print_callback` in `push_helper` | `# PUSH TO REMOTE HELPER` | Fresh repo with no commits | Yellow BG: `◎ No commits found. Commit something before pushing` |
| CB-07 | Callback when branch is behind remote | `print_callback` in `push_helper` | `# PUSH TO REMOTE HELPER` | Remote has unpulled commits | Yellow BG: `◎ Branch behind remote. Pull before pushing` with `git pull` hint |
| CB-08 | Callback when push fails | `print_callback` in `push_helper` | `# PUSH TO REMOTE HELPER` | Bad token or network error | Red BG: `✘ Push failed` with SSH key tip |
| PUSH-01 | Check `.git` before any push operation | `[ ! -d ".git" ]` | `# PUSH TO REMOTE HELPER` | Push from non-repo dir | Gate 1 fires, early return |
| PUSH-02 | Check remote is configured before pushing | `git remote` empty check | `# PUSH TO REMOTE HELPER` | Repo with no origin | Gate 2 fires, early return |
| PUSH-03 | Check at least one commit exists before pushing | `git rev-parse HEAD` | `# PUSH TO REMOTE HELPER` | Fresh repo, no commits | Gate 3 fires, early return |
| PUSH-04 | Check branch ahead/behind status before pushing | `git status --porcelain=v1 --branch` | `# PUSH TO REMOTE HELPER` | Branch behind remote | Gate 4 fires, early return |
| PUSH-05 | Extract ahead count with `sed` (macOS compatible) | `sed 's/.*ahead \([0-9]*\).*/\1/'` | `# PUSH TO REMOTE HELPER` | Branch 2 commits ahead | `2 commit(s) ready to push.` printed correctly on macOS |
| PUSH-06 | Capture push exit code immediately after `git push` | `local exit_status=$?` | `# PUSH TO REMOTE HELPER` | Trigger push failure | Non-zero exit captured before `stop_spinner` clears `$?` |
| PUSH-07 | Show animated spinner during push | `start_spinner` / `stop_spinner` | `# PUSH TO REMOTE HELPER` | Trigger a push | Braille animation visible during network operation |
| SYS-01 | Restore cursor on script exit via trap | `trap 'show_cursor...' EXIT` | `# TERMINAL UTILS` | Kill script mid-run | Cursor restored, terminal usable |
| SYS-02 | Install as global binary via `/usr/local/bin` | `sudo cp git-sync.sh /usr/local/bin/git-sync` | Installation docs | Run `git-sync` from any dir after install | Script executes from `PATH` |
| SYS-03 | Auto-trigger before `python` / `python3` / `node` via Zsh alias | `run_with_sync` wrapper in `~/.zshrc` | Installation docs | Run `python3 main.py` | Git-Sync UI opens first, then python3 runs |
| SYS-04 | VS Code integrated terminal inherits Zsh aliases | Shell profile inheritance | Installation docs | Run `python3` in VS Code terminal | Git-Sync fires without extra configuration |
| SYS-05 | Spinner runs as forked background subprocess | `( while true ... ) &` + `SPINNER_PID=$!` | `# SPINNER` | Observe any spinner | Braille animates while git operation runs in foreground |
| SYS-06 | Spinner killed cleanly with `wait` after stop | `kill $SPINNER_PID; wait $SPINNER_PID` | `# SPINNER` | Stop spinner after operation | No zombie process, line cleared with `\r\033[2K` |

---

## Coverage Summary

| Category | Total Requirements | Status |
|---|---|---|
| UI | 10 | ✅ All implemented |
| NAV | 11 | ✅ All implemented |
| GIT | 12 | ✅ All implemented |
| CB | 8 | ✅ All implemented |
| PUSH | 7 | ✅ All implemented |
| SYS | 6 | ✅ All implemented |
| **Total** | **54** | **✅ 54 / 54** |

---

*Last updated: v2.0 — includes arrow-key navigation, push_helper, callback system, and macOS bash 3.2 compatibility fix.*
