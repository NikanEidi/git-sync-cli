# Changelog — Git-Sync

All notable changes to this project are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.0.0] — Current

### Added

- **Arrow-key navigation** — `↑` and `↓` move a live highlight across menu rows. Selection state stored in `selected` integer variable inside `menu()` loop.
- **`MENU_ITEMS` array** — Three menu entries declared as a Bash array so `draw_menu`, navigation math, and the `ENTER` dispatch all reference one source of truth.
- **`draw_menu(selected)` parameter** — Menu renderer now accepts the focused index and renders the active row with `❯` prefix and per-row background color. Inactive rows render dim.
- **`push_helper()` function** — Full Push to Remote workflow with four sequential pre-flight gates: `.git` check, remote check, HEAD commit check, ahead/behind status check. Executes `git push origin branch` only when all gates pass.
- **`print_callback()` helper** — Unified function that renders a full-width highlighted banner block. Accepts icon, message, background color, and foreground color. Used for all eight terminal state conditions.
- **`BG_WARN` and `BG_ERROR`** — Two new background color variables added to the palette for callback block rendering.
- **Staged diff pre-check** — After `git add`, `git diff --cached --name-only` is run. If the result is empty the commit prompt is skipped entirely and a callback fires instead.
- **Staged file preview** — Before asking for a commit message, each staged file is listed with a `+` prefix so the user sees exactly what is about to be committed.
- **Commit exit code capture** — `local commit_status=$?` captured immediately after `git commit` before `stop_spinner` can overwrite `$?`.
- **Push exit code capture** — `local exit_status=$?` captured immediately after `git push` before `stop_spinner`.
- **`sed`-based ahead count extraction** — Replaced `grep -oP` (Linux-only Perl regex) with `sed 's/.*ahead \([0-9]*\).*/\1/'` which works identically on macOS BSD sed and GNU sed.
- **Direct key shortcuts** — Keys `1` and `3` bypass selection state and call their respective helpers immediately from anywhere in the menu loop.

### Fixed

- **Arrow keys triggering goodbye on macOS** — Root cause: macOS bash 3.2 does not support fractional second timeouts (`-t 0.05`). The old code read 2 bytes with `-rsn2 -t 0.05`; on macOS this silently returned empty, making every arrow key appear as a bare `ESC` which triggered the exit branch. Fixed by reading one byte at a time with integer `-t 1` timeouts: `b1` then `b2`, checking for `[` then `A`/`B`.
- **`grep -oP` failing on macOS** — BSD grep does not support `-P` (Perl-compatible regex). The `ahead_count` extraction returned empty. Replaced with portable `sed`.
- **Section header misalignment for "Push to Remote"** — Extra leading/trailing spaces in the title string caused off-center rendering inside the fixed 44-char box. Removed padding from the title argument.
- **Commit message prompt invisible** — `get_commit_message` called inside `$()` subshell; all stdout was captured instead of displayed. Fixed by redirecting all prompt output to `/dev/tty` and reading from `/dev/tty`.
- **Ghost key `2` in `read_key` and `case`** — Key `2` was mapped in `read_key` and triggered `ESC|QUIT|2` exit without being shown in the menu. Removed to eliminate hidden behavior.

### Changed

- `draw_menu()` now accepts a `$1` index parameter instead of rendering static rows.
- `read_key()` rewritten from two-byte read to byte-by-byte with `b1`/`b2` locals.
- Menu hint bar updated: `↑↓ navigate · ↵ confirm · 1 Sync · 3 Push · Esc/Q Quit`.
- `section_header "  Push to Remote  "` → `section_header "Push to Remote"` (padding removed).
- Banner color changed from `GREEN` (`\033[38;5;82m`) to `MAGENTA` (`\033[38;5;171m`) neon purple.

---

## [1.1.0]

### Added

- `push_helper()` initial implementation (Linux-only, later fixed in 2.0.0).
- Key `3` wired to `push_helper` in `read_key` and `menu` case block.
- `BG_WARN` and `BG_ERROR` background color variables.
- `print_callback()` unified feedback renderer.
- Staged diff check before commit prompt.
- Staged file list preview before commit.

### Fixed

- Commit message prompt swallowed by subshell — redirected to `/dev/tty`.

---

## [1.0.0] — Initial Release

### Added

- `menu()` main loop with `draw_menu` / `read_key` / `case` dispatch.
- `initializer_helper()` — git init, gitignore, glob, stage, commit.
- `gitignore_creator_helper()` — idempotent `.gitignore` scaffold.
- `get_commit_message()` — styled commit prompt.
- `draw_banner()` — ASCII art header.
- `section_header()` — box-drawn panel.
- `hr()` — terminal-width horizontal rule.
- `print_success/error/info/warn/step()` — styled one-line outputs.
- `start_spinner()` / `stop_spinner()` — background braille animation.
- `read_key()` — raw single-keypress reader with ESC detection.
- ANSI 256-color palette with semantic aliases.
- `trap` for unconditional cursor restore on exit.
- Enter and `Q`/`q` and `ESC` keyboard handling.
