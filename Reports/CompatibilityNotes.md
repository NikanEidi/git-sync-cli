# Compatibility Notes — Git-Sync

> Documents every platform-specific behavior, known incompatibility, workaround applied, and environment requirement for running Git-Sync correctly.

---

## Supported Environments

| Environment | Status | Notes |
|---|---|---|
| macOS (bash 3.2) | ✅ Fully supported | Default shell on macOS pre-Catalina |
| macOS (bash 5+, Homebrew) | ✅ Fully supported | |
| macOS (zsh 5+) | ✅ Fully supported | Run via `bash git-sync.sh` or install to PATH |
| Ubuntu / Debian (bash 5+) | ✅ Fully supported | |
| Arch Linux (bash 5+) | ✅ Fully supported | |
| WSL2 (bash 5+) | ✅ Fully supported | Terminal must support ANSI 256 color |
| Windows (native) | ❌ Not supported | No bash, no POSIX terminal |
| Alpine Linux (busybox sh) | ❌ Not supported | `read -rsn1` and ANSI codes not supported |

---

## Known Incompatibilities & Applied Fixes

---

### 1. Fractional `-t` timeout in `read` (macOS bash 3.2)

**Problem:** The original `read_key` used:
```bash
IFS= read -rsn2 -t 0.05 seq 2>/dev/null
```
On macOS bash 3.2, fractional second timeouts in `read -t` are not supported. The value `0.05` is silently treated as invalid and the read returns immediately with an empty string. This caused every arrow key (`\x1b [ A`) to be misidentified as a bare `ESC` keypress, triggering the exit branch instead of navigation.

**Fix applied:** Replaced with byte-by-byte reading using integer timeout `-t 1`:
```bash
IFS= read -rsn1 -t 1 b1 2>/dev/null
IFS= read -rsn1 -t 1 b2 2>/dev/null
```
Integer `-t 1` is supported in all bash versions. Since arrow key byte sequences are emitted atomically by the terminal, the 1-second timeout is never actually waited on during normal use.

**Affected versions:** macOS bash 3.2 (all macOS up to and including Big Sur with system bash).

---

### 2. `grep -oP` Perl-compatible regex (macOS BSD grep)

**Problem:** The push_helper used:
```bash
ahead_count=$(echo "$upstream_check" | grep -oP 'ahead \K[0-9]+')
```
macOS ships BSD grep, which does not support the `-P` flag for Perl-compatible regular expressions. The command fails with:
```
grep: invalid option -- P
```
And `ahead_count` remains empty, producing output like `  commit(s) ready to push.` with no number.

**Fix applied:** Replaced with POSIX BRE `sed`:
```bash
ahead_count=$(echo "$upstream_check" | sed 's/.*ahead \([0-9]*\).*/\1/')
```
This works identically on BSD sed (macOS) and GNU sed (Linux).

**Affected versions:** macOS (all versions with system grep).

---

### 3. Commit message prompt invisible inside subshell

**Problem:** `get_commit_message` is called as:
```bash
result=$(get_commit_message)
```
The `$()` construct creates a subshell. All stdout inside the subshell is captured by the assignment rather than displayed to the terminal. Every `echo` and `printf` inside `get_commit_message` was silently swallowed, making the commit prompt completely invisible.

**Fix applied:** All prompt output redirected to `/dev/tty` (the actual controlling terminal, always writable regardless of stdout capture). Input is read from `/dev/tty` as well:
```bash
echo -e "  Commit Message" >/dev/tty
printf "  ❯  " >/dev/tty
read -r msg </dev/tty
```
Only the final `echo "${msg:-Automatic sync commit}"` goes to stdout, which is correctly captured by the `$()`.

---

### 4. `tree` command availability

**Problem:** The `tree` command used to display directory structure is not installed by default on all systems.

**Behavior:** Git-Sync checks for `tree` with `command -v tree >/dev/null 2>&1`. If not found, it falls back to a manual `printf` loop over the `real_files` array.

**To install tree:**
```bash
# macOS
brew install tree

# Ubuntu / Debian
sudo apt install tree

# Arch
sudo pacman -S tree
```

---

### 5. 256-color ANSI terminal requirement

**Problem:** Git-Sync uses `\033[38;5;Nm` and `\033[48;5;Nm` 256-color escape sequences. Terminals that only support 8 or 16 colors will display incorrect or no colors.

**Verification:**
```bash
echo $TERM
# Should return: xterm-256color, screen-256color, or similar
```

**Common supported terminals:** iTerm2, Terminal.app (macOS 10.7+), GNOME Terminal, Alacritty, Kitty, VS Code integrated terminal, Windows Terminal (WSL2).

---

### 6. Zsh compatibility when run directly

Git-Sync uses `#!/bin/bash` and is written for bash. On macOS the default interactive shell is zsh (since Catalina). Running `./git-sync.sh` invokes bash via the shebang regardless of the user's interactive shell. Running `zsh git-sync.sh` would fail due to bash-specific syntax (`[[ ]]`, `local`, array syntax differences).

**Correct invocation:**
```bash
bash git-sync.sh       # explicit
./git-sync.sh          # uses shebang #!/bin/bash
git-sync               # after install to /usr/local/bin (shebang used)
```

---

### 7. `git branch --show-current` availability

`git branch --show-current` was added in Git 2.22. On systems with older Git versions this will return empty.

**Minimum Git version required:** 2.22.0 (June 2019).

**Verification:**
```bash
git --version
```

---

## Environment Requirements Summary

| Requirement | Minimum Version | Notes |
|---|---|---|
| bash | 3.2+ | macOS system bash is 3.2 and is fully supported |
| git | 2.22+ | Required for `git branch --show-current` |
| Terminal | 256-color | `$TERM` should be `xterm-256color` or equivalent |
| OS | macOS 10.9+ / Linux | POSIX-compliant system |
| `sed` | Any POSIX sed | BSD or GNU both supported |
| `grep` | Any POSIX grep | `-P` flag explicitly avoided |
| `tput` | Any | Falls back to 60 cols if unavailable |
| `tree` | Any | Optional — fallback list used if missing |
