#!/bin/bash

# ─────────────────────────────────────────────
#  THEME & COLOR PALETTE
# ─────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

BLACK="\033[30m"
RED="\033[38;5;196m"
GREEN="\033[38;5;82m"
YELLOW="\033[38;5;220m"
CYAN="\033[38;5;51m"
BLUE="\033[38;5;33m"
MAGENTA="\033[38;5;171m"
WHITE="\033[97m"

BG_DARK="\033[48;5;232m"
BG_PANEL="\033[48;5;17m"
BG_HIGHLIGHT="\033[48;5;22m"
BG_WARN="\033[48;5;52m"
BG_ERROR="\033[48;5;88m"

ACCENT="${BOLD}${GREEN}"
MUTED="${DIM}${WHITE}"
DANGER="${BOLD}${RED}"
INFO="${BOLD}${CYAN}"
WARN="${BOLD}${YELLOW}"

# ─────────────────────────────────────────────
#  TERMINAL UTILS
# ─────────────────────────────────────────────
clear_screen()  { printf "\033[2J\033[H"; }
hide_cursor()   { printf "\033[?25l"; }
show_cursor()   { printf "\033[?25h"; }
move_to()       { printf "\033[%s;%sH" "$1" "$2"; }

# trap to always restore cursor on exit
trap 'show_cursor; tput cnorm 2>/dev/null; echo ""' EXIT

# ─────────────────────────────────────────────
#  SPINNER
# ─────────────────────────────────────────────
SPINNER_PID=""
spinner_frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

start_spinner() {
    local label="${1:-Working...}"
    hide_cursor
    (
        local i=0
        while true; do
            printf "\r  ${ACCENT}${spinner_frames[$i]}${RESET}  ${MUTED}${label}${RESET}   "
            i=$(( (i + 1) % ${#spinner_frames[@]} ))
            sleep 0.08
        done
    ) &
    SPINNER_PID=$!
}

stop_spinner() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
        SPINNER_PID=""
        printf "\r\033[2K"
    fi
    show_cursor
}

# ─────────────────────────────────────────────
#  STYLED OUTPUT HELPERS
# ─────────────────────────────────────────────
print_success() { echo -e "  ${ACCENT}✔${RESET}  ${WHITE}${1}${RESET}"; }
print_error()   { echo -e "  ${DANGER}✘${RESET}  ${WHITE}${1}${RESET}"; }
print_info()    { echo -e "  ${INFO}ℹ${RESET}  ${WHITE}${1}${RESET}"; }
print_warn()    { echo -e "  ${WARN}⚠${RESET}  ${WHITE}${1}${RESET}"; }
print_step()    { echo -e "  ${MAGENTA}›${RESET}  ${MUTED}${1}${RESET}"; }
print_blank()   { echo ""; }

# highlighted banner-style callback block for user-facing state messages
print_callback() {
    local icon="$1"
    local msg="$2"
    local bg="$3"
    local fg="$4"
    print_blank
    echo -e "  ${bg}${fg}${BOLD}  ${icon}  ${msg}  ${RESET}"
    print_blank
}

# Horizontal rule
hr() {
    local char="${1:-─}"
    local color="${2:-$MUTED}"
    local cols=$(tput cols 2>/dev/null || echo 60)
    local line=""
    for ((i=0; i<cols-4; i++)); do line+="$char"; done
    echo -e "  ${color}${line}${RESET}"
}

# Boxed section header
section_header() {
    local title="$1"
    local box_inner=44
    local title_len=${#title}
    local total_pad=$(( box_inner - title_len ))
    local pad_left=$(( total_pad / 2 ))
    local pad_right=$(( total_pad - pad_left ))
    local left_spaces right_spaces
    left_spaces=$(printf '%*s' "$pad_left" '')
    right_spaces=$(printf '%*s' "$pad_right" '')
    local top_border="┌$(printf '─%.0s' $(seq 1 $box_inner))┐"
    local bot_border="└$(printf '─%.0s' $(seq 1 $box_inner))┘"
    print_blank
    echo -e "  \033[38;5;171m${DIM}${top_border}${RESET}"
    echo -e "  \033[38;5;171m${DIM}│${RESET}${left_spaces}${BOLD}\033[38;5;171m${title}${RESET}${right_spaces}  \033[38;5;171m${DIM}│${RESET}"
    echo -e "  \033[38;5;171m${DIM}${bot_border}${RESET}"
    print_blank
}

# ─────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────
draw_banner() {
    clear_screen
    print_blank
    echo -e "\033[38;5;171m${BOLD}"
    echo "   ██████  ██ ████████     ███████ ██    ██ ███    ██  ██████ "
    echo "  ██       ██    ██        ██       ██  ██  ████   ██ ██      "
    echo "  ██   ███ ██    ██  ████  ███████   ████   ██ ██  ██ ██      "
    echo "  ██    ██ ██    ██        ╚════██    ██    ██  ██ ██ ██      "
    echo "   ██████  ██    ██        ███████    ██    ██   ████  ██████ "
    echo -e "${RESET}"
    echo -e "  ${MUTED}──────────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${DIM}${WHITE}   Seamless Git Automation${RESET}   ${DIM}·${RESET}   ${DIM}\033[38;5;171mv2.0${RESET}"
    echo -e "  ${MUTED}──────────────────────────────────────────────────────────────${RESET}"
    print_blank
}

# ─────────────────────────────────────────────
#  KEY READER  (single keypress, ESC-aware)
# ─────────────────────────────────────────────
read_key() {
    local key
    IFS= read -rsn1 key 2>/dev/null
    # if ESC byte, check for escape sequence vs bare ESC
    if [[ "$key" == $'\x1b' ]]; then
        local seq
        IFS= read -rsn2 -t 0.05 seq 2>/dev/null
        if [[ -z "$seq" ]]; then
            # no follow-up bytes — user pressed bare ESC key
            echo "ESC"
        elif [[ "$seq" == "[A" ]]; then
            # ANSI sequence for arrow up key
            echo "UP"
        elif [[ "$seq" == "[B" ]]; then
            # ANSI sequence for arrow down key
            echo "DOWN"
        else
            echo "SEQ:${seq}"
        fi
    elif [[ "$key" == "" ]]; then
        echo "ENTER"
    elif [[ "$key" == "q" || "$key" == "Q" ]]; then
        echo "QUIT"
    elif [[ "$key" == "1" ]]; then
        # key 1 maps to Run Git-Sync as shown in the menu
        echo "1"
    elif [[ "$key" == "3" ]]; then
        # key 3 maps to Push to Remote as shown in the menu
        echo "3"
    else
        echo "OTHER:${key}"
    fi
}

# ─────────────────────────────────────────────
#  COMMIT MESSAGE INPUT  (styled)
# ─────────────────────────────────────────────
# get commit message from user
function get_commit_message(){
    print_blank >/dev/tty
    echo -e "  ${BOLD}\033[38;5;171mCommit Message${RESET}" >/dev/tty
    echo -e "  ${MUTED}Leave blank for default → \"Automatic sync commit\"${RESET}" >/dev/tty
    print_blank >/dev/tty
    printf "  ${BOLD}\033[38;5;171m❯${RESET}  " >/dev/tty
    show_cursor
    # ask user for commit message
    read -r msg </dev/tty
    echo "${msg:-Automatic sync commit}"
}

# ─────────────────────────────────────────────
#  GITIGNORE CREATOR
# ─────────────────────────────────────────────
# create .gitignore file with common patterns
function gitignore_creator_helper(){
    if [ ! -f ".gitignore" ]; then
        print_step "Creating .gitignore file..."
        cat <<EOF > .gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
vwen/
env/
.env
# JavaScript / Node
node_modules/
npm-debug.log*
# OS files
.DS_Store
Thumbs.db
# IDEs
.vscode/
.idea/
*.swp
# Logs
*.log
EOF
        print_success ".gitignore created successfully."
    else
        print_warn ".gitignore already exists, skipping."
    fi
}

# ─────────────────────────────────────────────
#  GIT PROCESS HELPER
# ─────────────────────────────────────────────
# git process helper
function initializer_helper(){
    section_header "  Git Sync  "

    local checker=1  # initialize checker
    if [ -d ".git" ]; then
        print_info "Repository already initialized."
        checker=-1
    else
        print_warn "No git repository found. Initializing..."
        checker=0
        print_blank
        # Initialize git in project root
        start_spinner "Running git init..."
        git init > /dev/null 2>&1
        stop_spinner
        print_success "Repository initialized."

        # call gitignore creator after init
        gitignore_creator_helper
    fi

    print_blank
    hr "·"
    print_blank

    # Collect only regular files
    local real_files=()
    # Improved loop to include hidden files like .gitignore but skip .git folder
    for f in .[!.]* *; do
        if [ -e "$f" ] && [ "$f" != ".git" ]; then
            real_files+=("$f")
        fi
    done

    local f_counter=${#real_files[@]}  # count files

    # Initialize add conditions for less or more than 1 file
    if [[ "$f_counter" -eq 0 ]]; then
        # no files exist at all in the directory — nothing to stage
        print_callback "◎" "No files found in this directory. Nothing to stage." "$BG_WARN" "$YELLOW"
        return
    elif [[ "$f_counter" -eq 1 ]]; then
        print_step "One file found:"
        echo -e "     ${ACCENT}▸${RESET}  ${WHITE}${real_files[0]}${RESET}"
        print_blank
        start_spinner "Staging file..."
        git add "${real_files[0]}" 2>/dev/null
        stop_spinner
        print_success "File staged."
    else
        print_info "${f_counter} files detected:"
        print_blank
        # Show the current directory structure as a tree before adding
        if command -v tree >/dev/null 2>&1; then
            # Ignore .git folder in tree output to match actual staging count
            tree -L 1 -a -I '.git' --noreport 2>/dev/null | tail -n +2 | while IFS= read -r line; do
                echo -e "     ${DIM}\033[38;5;171m${line}${RESET}"
            done
        else
            echo "     --- Current Directory Files ---"
            printf '%s\n' "${real_files[@]}" | while IFS= read -r f; do
                echo -e "     ${DIM}\033[38;5;171m▸  ${WHITE}${f}${RESET}"
            done
        fi
        print_blank
        start_spinner "Staging all files..."
        git add . 2>/dev/null
        stop_spinner
        print_success "All files staged."
    fi

    print_blank
    hr "·"
    print_blank

    # check the index for staged changes — git status porcelain returns empty if nothing is staged
    local staged_check
    staged_check=$(git diff --cached --name-only 2>/dev/null)
    if [[ -z "$staged_check" ]]; then
        # the working tree matches the last commit — no diff to record
        print_callback "◎" "Nothing to commit. Your repo is already up to date." "$BG_WARN" "$YELLOW"
        print_step "No changes were detected since your last commit."
        print_blank
        hr
        print_blank
        return
    fi

    # show which files are about to be committed
    print_info "Changes staged for commit:"
    print_blank
    echo "$staged_check" | while IFS= read -r staged_file; do
        echo -e "     ${ACCENT}+${RESET}  ${WHITE}${staged_file}${RESET}"
    done
    print_blank
    hr "·"

    # call commit message getter and store the result
    local result
    result=$(get_commit_message)

    print_blank
    start_spinner "Committing..."
    sleep 0.4
    git commit -m "$result" > /dev/null 2>&1
    local commit_status=$?  # capture commit exit code immediately
    stop_spinner

    # report the commit outcome with the appropriate callback block
    if [[ "$commit_status" -eq 0 ]]; then
        print_blank
        echo -e "  ${BG_HIGHLIGHT}${BOLD}${WHITE}  ✔  Committed: \"${result}\"  ${RESET}"
    else
        print_callback "✘" "Commit failed. Check your git config or staged state." "$BG_ERROR" "$RED"
    fi

    print_blank
    hr
    print_blank
}

# ─────────────────────────────────────────────
#  PUSH TO REMOTE HELPER
# ─────────────────────────────────────────────
# push current branch to configured remote origin
function push_helper(){
    section_header "  Push to Remote  "

    # abort if no git repository exists in the current directory
    if [ ! -d ".git" ]; then
        print_callback "✘" "No git repository found. Run Git-Sync first." "$BG_ERROR" "$RED"
        print_step "Initialize a repo with option 1 before pushing."
        print_blank
        hr
        print_blank
        return
    fi

    # abort if no remote is configured
    local remote_check
    remote_check=$(git remote 2>/dev/null)
    if [[ -z "$remote_check" ]]; then
        print_callback "◎" "No remote origin configured. Cannot push." "$BG_WARN" "$YELLOW"
        print_step "Run:  git remote add origin <your-repo-url>"
        print_blank
        hr
        print_blank
        return
    fi

    # resolve the active branch name at call time
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)

    # check that there is at least one commit before attempting to push
    if ! git rev-parse HEAD > /dev/null 2>&1; then
        print_callback "◎" "No commits found. Commit something before pushing." "$BG_WARN" "$YELLOW"
        print_step "Stage and commit your files with option 1 first."
        print_blank
        hr
        print_blank
        return
    fi

    # check if local branch is ahead of remote — if not, nothing new to push
    local upstream_check
    upstream_check=$(git status --porcelain=v1 --branch 2>/dev/null | grep "^##")
    if echo "$upstream_check" | grep -q "ahead"; then
        # local has commits the remote does not — safe to push
        local ahead_count
        ahead_count=$(echo "$upstream_check" | grep -oP 'ahead \K[0-9]+')
        print_info "Remote: $(git remote get-url origin 2>/dev/null)"
        print_step "Branch: ${current_branch}"
        print_step "${ahead_count} commit(s) ready to push."
    elif echo "$upstream_check" | grep -q "behind"; then
        # remote is ahead of local — push would be rejected anyway
        print_callback "◎" "Your branch is behind the remote. Pull before pushing." "$BG_WARN" "$YELLOW"
        print_step "Run:  git pull origin ${current_branch}"
        print_blank
        hr
        print_blank
        return
    else
        # no tracking branch set or branch is already up to date
        print_info "Remote: $(git remote get-url origin 2>/dev/null)"
        print_step "Branch: ${current_branch}"
        print_warn "Branch may already be up to date with remote."
    fi

    print_blank
    hr "·"
    print_blank

    # animate while the push runs in the foreground
    start_spinner "Pushing to origin... (Branch: ${current_branch})"
    git push origin "${current_branch}" > /dev/null 2>&1
    local exit_status=$?  # capture push exit code before any other command runs
    stop_spinner

    # report outcome based on the captured exit code
    if [[ "$exit_status" -eq 0 ]]; then
        print_blank
        echo -e "  ${BG_HIGHLIGHT}${BOLD}${WHITE}  ✔  Successfully pushed to origin/${current_branch}  ${RESET}"
    else
        print_callback "✘" "Push failed. Check your network or resolve conflicts." "$BG_ERROR" "$RED"
        print_step "Tip: make sure your SSH key or token is valid."
    fi

    print_blank
    hr
    print_blank
}

# ─────────────────────────────────────────────
#  MENU RENDERER  (arrow-key aware, selected index driven)
# ─────────────────────────────────────────────
# menu items array — order defines arrow navigation order
MENU_ITEMS=("Run Git-Sync" "Push to Remote" "Exit")
MENU_COUNT=${#MENU_ITEMS[@]}

# draw the menu with the currently selected row highlighted
draw_menu() {
    local selected=$1  # index of the currently focused row
    draw_banner
    echo -e "  ${BOLD}${WHITE}Select an action${RESET}"
    print_blank

    local i
    for (( i=0; i<MENU_COUNT; i++ )); do
        if [[ "$i" -eq "$selected" ]]; then
            # active row — render with full highlight and selection arrow
            if [[ "$i" -eq 0 ]]; then
                # Run Git-Sync row — purple highlight
                echo -e "  \033[48;5;54m\033[38;5;171m${BOLD}  ❯  ${MENU_ITEMS[$i]}$(printf '%*s' 33 '')${RESET}   ${MUTED}1 or Enter${RESET}"
            elif [[ "$i" -eq 1 ]]; then
                # Push to Remote row — cyan highlight
                echo -e "  \033[48;5;17m\033[38;5;51m${BOLD}  ❯  ${MENU_ITEMS[$i]}$(printf '%*s' 35 '')${RESET}   ${MUTED}3${RESET}"
            else
                # Exit row — dim red highlight
                echo -e "  \033[48;5;52m\033[38;5;196m${BOLD}  ❯  ${MENU_ITEMS[$i]}$(printf '%*s' 39 '')${RESET}   ${MUTED}Esc / Q${RESET}"
            fi
        else
            # inactive row — render dim without arrow
            if [[ "$i" -eq 0 ]]; then
                echo -e "  ${DIM}     ${MENU_ITEMS[$i]}$(printf '%*s' 33 '')${RESET}   ${MUTED}1 or Enter${RESET}"
            elif [[ "$i" -eq 1 ]]; then
                echo -e "  ${DIM}     ${MENU_ITEMS[$i]}$(printf '%*s' 35 '')${RESET}   ${MUTED}3${RESET}"
            else
                echo -e "  ${DIM}     ${MENU_ITEMS[$i]}$(printf '%*s' 39 '')${RESET}   ${MUTED}Esc / Q${RESET}"
            fi
        fi
        print_blank
    done

    hr "─" "$MUTED"
    echo -e "  ${MUTED}  ↑↓ navigate  ·  ↵ confirm  ·  1 Sync  ·  3 Push  ·  Esc/Q Quit${RESET}"
    print_blank
}

# ─────────────────────────────────────────────
#  MENU  (main entry of Program)
# ─────────────────────────────────────────────
# main entry of Program
function menu(){
    local selected=0  # start with the first item focused

    while true; do
        hide_cursor  # Ensure cursor remains hidden when menu redraws
        draw_menu "$selected"
        # read a single keypress (no Enter needed)
        local choice
        choice=$(read_key)

        case "$choice" in
            UP)
                # move selection up and wrap around to the bottom
                selected=$(( (selected - 1 + MENU_COUNT) % MENU_COUNT ))
                ;;
            DOWN)
                # move selection down and wrap around to the top
                selected=$(( (selected + 1) % MENU_COUNT ))
                ;;
            ENTER)
                # confirm the currently focused item
                case "$selected" in
                    0) # run the git helper or Enter
                       initializer_helper
                       print_blank
                       echo -e "  ${MUTED}Press any key to return to menu...${RESET}"
                       read_key > /dev/null
                       ;;
                    1) # push staged commits to the configured remote origin
                       push_helper
                       print_blank
                       echo -e "  ${MUTED}Press any key to return to menu...${RESET}"
                       read_key > /dev/null
                       ;;
                    2) # exit loop with ESC or q
                       clear_screen
                       draw_banner
                       echo -e "  ${ACCENT}✔${RESET}  ${MUTED}Session ended. Goodbye.${RESET}"
                       print_blank
                       return
                       ;;
                esac
                ;;
            1)
                # key 1 directly triggers Run Git-Sync regardless of current selection
                initializer_helper
                print_blank
                echo -e "  ${MUTED}Press any key to return to menu...${RESET}"
                read_key > /dev/null
                ;;
            3)
                # key 3 directly triggers Push to Remote regardless of current selection
                push_helper
                print_blank
                echo -e "  ${MUTED}Press any key to return to menu...${RESET}"
                read_key > /dev/null
                ;;
            ESC|QUIT)
                # exit loop with ESC or q
                clear_screen
                draw_banner
                echo -e "  ${ACCENT}✔${RESET}  ${MUTED}Session ended. Goodbye.${RESET}"
                print_blank
                break
                ;;
            *)
                # invalid input — just redraw silently
                ;;
        esac
    done
}

# start the program
menu