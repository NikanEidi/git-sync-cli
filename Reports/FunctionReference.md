# Function Reference — Git-Sync

> Complete API-style reference for every function in `git-sync.sh`. Lists signature, parameters, return values, side effects, and dependencies for each function.

---

## Utility Layer

---

### `clear_screen()`
Clears the terminal and moves cursor to position 0,0.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | nothing |
| **Side effects** | writes `\033[2J\033[H` to stdout |
| **Dependencies** | none |

---

### `hide_cursor()`
Hides the terminal cursor using ANSI private mode sequence.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | nothing |
| **Side effects** | writes `\033[?25l` to stdout |
| **Dependencies** | none |

---

### `show_cursor()`
Restores the terminal cursor.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | nothing |
| **Side effects** | writes `\033[?25h` to stdout |
| **Dependencies** | none |

---

### `move_to(row, col)`
Moves cursor to absolute terminal position.

| | |
|---|---|
| **Parameters** | `$1` row, `$2` col (1-indexed) |
| **Returns** | nothing |
| **Side effects** | writes ANSI cursor position escape |
| **Dependencies** | none |

---

### `print_blank()`
Prints one empty line.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | nothing |
| **Side effects** | writes `\n` to stdout |
| **Dependencies** | none |

---

### `print_success(message)`
Prints a green checkmark line.

| | |
|---|---|
| **Parameters** | `$1` message string |
| **Returns** | nothing |
| **Side effects** | writes `  ✔  message` to stdout |
| **Dependencies** | `ACCENT`, `WHITE`, `RESET` |

---

### `print_error(message)`
Prints a red X line.

| | |
|---|---|
| **Parameters** | `$1` message string |
| **Returns** | nothing |
| **Side effects** | writes `  ✘  message` to stdout |
| **Dependencies** | `DANGER`, `WHITE`, `RESET` |

---

### `print_info(message)`
Prints a cyan info line.

| | |
|---|---|
| **Parameters** | `$1` message string |
| **Returns** | nothing |
| **Side effects** | writes `  ℹ  message` to stdout |
| **Dependencies** | `INFO`, `WHITE`, `RESET` |

---

### `print_warn(message)`
Prints a yellow warning line.

| | |
|---|---|
| **Parameters** | `$1` message string |
| **Returns** | nothing |
| **Side effects** | writes `  ⚠  message` to stdout |
| **Dependencies** | `WARN`, `WHITE`, `RESET` |

---

### `print_step(message)`
Prints a magenta step/process line.

| | |
|---|---|
| **Parameters** | `$1` message string |
| **Returns** | nothing |
| **Side effects** | writes `  ›  message` to stdout |
| **Dependencies** | `MAGENTA`, `MUTED`, `RESET` |

---

### `print_callback(icon, message, bg, fg)`
Renders a full-width highlighted callback banner block. Used for all terminal state feedback conditions — nothing to commit, push failed, branch behind, etc.

| | |
|---|---|
| **Parameters** | `$1` icon symbol · `$2` message string · `$3` BG color variable · `$4` FG color variable |
| **Returns** | nothing |
| **Side effects** | writes blank + colored banner + blank to stdout |
| **Dependencies** | `BOLD`, `RESET`, `print_blank` |

**Example calls:**
```bash
print_callback "◎" "Nothing to commit." "$BG_WARN" "$YELLOW"
print_callback "✘" "Push failed."       "$BG_ERROR" "$RED"
```

---

### `hr([char], [color])`
Prints a full terminal-width horizontal rule.

| | |
|---|---|
| **Parameters** | `$1` character (default `─`) · `$2` ANSI color (default `$MUTED`) |
| **Returns** | nothing |
| **Side effects** | writes colored line to stdout; reads `tput cols` |
| **Dependencies** | `MUTED`, `RESET`, `tput` |

---

### `section_header(title)`
Renders a centered box-drawn panel with neon-purple borders.

| | |
|---|---|
| **Parameters** | `$1` title string |
| **Returns** | nothing |
| **Side effects** | writes 3-line box + surrounding blank lines to stdout |
| **Dependencies** | `MAGENTA`, `BOLD`, `DIM`, `RESET`, `print_blank`, `printf`, `seq` |

**Box geometry:** Inner width fixed at 44 characters. Title is padded with spaces on left and right to achieve centering. `printf '%*s'` generates the padding strings.

---

## Spinner Subsystem

---

### `start_spinner(label)`
Forks a background subprocess that animates a braille spinner with a label.

| | |
|---|---|
| **Parameters** | `$1` label string (default `"Working..."`) |
| **Returns** | nothing — sets global `SPINNER_PID` |
| **Side effects** | forks subprocess · hides cursor · writes to stdout in a loop |
| **Dependencies** | `ACCENT`, `MUTED`, `RESET`, `hide_cursor`, `spinner_frames`, `SPINNER_PID` |

---

### `stop_spinner()`
Kills the spinner subprocess, waits for it to terminate, and clears the spinner line.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | nothing — clears global `SPINNER_PID` |
| **Side effects** | sends SIGTERM · waits for child · clears line · shows cursor |
| **Dependencies** | `SPINNER_PID`, `show_cursor` |

**Critical note:** `stop_spinner` resets `$?` internally via `kill`, `wait`, and `printf`. Always capture the exit code of any git command into a `local` variable *before* calling `stop_spinner`.

---

## Banner

---

### `draw_banner()`
Clears the screen and renders the full Git-Sync ASCII art header with subtitle and horizontal rules.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | nothing |
| **Side effects** | clears terminal · writes full banner to stdout |
| **Dependencies** | `clear_screen`, `print_blank`, `MAGENTA`, `BOLD`, `MUTED`, `DIM`, `WHITE`, `CYAN`, `RESET` |

---

## Key Reader

---

### `read_key()`
Reads a single raw keypress from stdin and returns a normalized string token. Handles bare ESC vs arrow key disambiguation without fractional timeouts.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | string token via `echo` to stdout |
| **Side effects** | consumes bytes from stdin (raw terminal mode assumed) |
| **Dependencies** | none — uses only `read` builtin |

**Return values:**

| Returned string | Trigger |
|---|---|
| `"ENTER"` | Enter key (empty string from `read`) |
| `"ESC"` | Bare Escape key |
| `"UP"` | `↑` arrow key (`\x1b [ A`) |
| `"DOWN"` | `↓` arrow key (`\x1b [ B`) |
| `"QUIT"` | `q` or `Q` |
| `"1"` | digit `1` |
| `"3"` | digit `3` |
| `"SEQ:..."` | unhandled escape sequence |
| `"OTHER:..."` | any other key |

---

## Commit Message Input

---

### `get_commit_message()`
Prompts the user for a commit message and echoes the result. Redirects all prompt output to `/dev/tty` and reads from `/dev/tty` to function correctly inside a `$()` subshell capture.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | message string via `echo` to stdout |
| **Side effects** | writes prompt to `/dev/tty` · shows cursor · reads from `/dev/tty` |
| **Dependencies** | `BOLD`, `MAGENTA`, `MUTED`, `RESET`, `print_blank`, `show_cursor` |

**Default behavior:** If the user presses Enter with no input, returns `"Automatic sync commit"` via parameter expansion `${msg:-Automatic sync commit}`.

---

## Gitignore Creator

---

### `gitignore_creator_helper()`
Creates a `.gitignore` file with standard patterns if one does not already exist.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | nothing |
| **Side effects** | may write `.gitignore` to current working directory |
| **Dependencies** | `print_step`, `print_success`, `print_warn` |

**Idempotent:** Safe to call multiple times. Skips and warns if `.gitignore` already exists.

---

## Git Process Helper

---

### `initializer_helper()`
Orchestrates the complete Git init → stage → commit workflow. Contains multiple early-return guard clauses for each invalid state.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | nothing (uses `return` for early exits) |
| **Side effects** | may run `git init`, `git add`, `git commit` · may create `.gitignore` · writes UI to stdout |
| **Dependencies** | `section_header`, `print_info/warn/step/success/callback`, `hr`, `print_blank`, `start_spinner`, `stop_spinner`, `gitignore_creator_helper`, `get_commit_message`, `BG_WARN`, `BG_ERROR`, `BG_HIGHLIGHT` |

**Guard clauses (in order):**
1. `f_counter == 0` → early return
2. `staged_check` empty → early return
3. `commit_status != 0` → callback, then continue to cleanup (no early return)

---

## Push to Remote Helper

---

### `push_helper()`
Validates all pre-conditions for a push then executes `git push origin branch`. Four sequential gates each produce distinct callback output if they fail.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | nothing (uses `return` for early exits on gate failure) |
| **Side effects** | may run `git push` · writes UI to stdout |
| **Dependencies** | `section_header`, `print_info/warn/step/callback`, `hr`, `print_blank`, `start_spinner`, `stop_spinner`, `BG_WARN`, `BG_ERROR`, `BG_HIGHLIGHT` |

**Gates (in order):**
1. `.git` directory exists
2. `git remote` non-empty
3. `git rev-parse HEAD` succeeds
4. branch is not behind remote

---

## Menu Renderer

---

### `draw_menu(selected)`
Renders the full menu screen with the active row highlighted. Called on every loop iteration before `read_key`.

| | |
|---|---|
| **Parameters** | `$1` integer — index of the focused menu row |
| **Returns** | nothing |
| **Side effects** | clears screen via `draw_banner` · writes full menu to stdout |
| **Dependencies** | `draw_banner`, `MENU_ITEMS`, `MENU_COUNT`, `BOLD`, `WHITE`, `DIM`, `MUTED`, `RESET`, `print_blank`, `hr` |

**Row colors when selected:**

| Row | BG | FG |
|---|---|---|
| 0 — Run Git-Sync | `\033[48;5;54m` (deep purple) | `\033[38;5;171m` (neon purple) |
| 1 — Push to Remote | `\033[48;5;17m` (dark navy) | `\033[38;5;51m` (neon cyan) |
| 2 — Exit | `\033[48;5;52m` (dark red) | `\033[38;5;196m` (bright red) |

---

## Main Loop

---

### `menu()`
Entry point and main program loop. Owns the `selected` navigation state variable. Dispatches to `initializer_helper`, `push_helper`, or exit based on keypress.

| | |
|---|---|
| **Parameters** | none |
| **Returns** | nothing — exits via `break` or `return` |
| **Side effects** | runs the entire program · calls all major subsystems |
| **Dependencies** | `hide_cursor`, `draw_menu`, `read_key`, `initializer_helper`, `push_helper`, `draw_banner`, `print_blank`, `ACCENT`, `MUTED`, `RESET`, `MENU_COUNT` |

**State variable:** `local selected=0` — integer tracking currently highlighted row. Range: `0` to `MENU_COUNT - 1`.

**Navigation math:**
```bash
UP:   selected=$(( (selected - 1 + MENU_COUNT) % MENU_COUNT ))
DOWN: selected=$(( (selected + 1) % MENU_COUNT ))
```
