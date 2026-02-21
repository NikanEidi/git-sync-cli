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
BG_PANEL="\033[48;5;234m"
BG_HIGHLIGHT="\033[48;5;22m"

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
    local len=${#title}
    local pad=$(( (40 - len) / 2 ))
    print_blank
    echo -e "  ${DIM}${CYAN}┌──────────────────────────────────────┐${RESET}"
    printf "  ${DIM}${CYAN}│${RESET}%${pad}s${BOLD}${CYAN}%s${RESET}%${pad}s  ${DIM}${CYAN}│${RESET}\n" "" "$title" ""
    echo -e "  ${DIM}${CYAN}└──────────────────────────────────────┘${RESET}"
    print_blank
}

# ─────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────
draw_banner() {
    clear_screen
    print_blank
    echo -e "${BOLD}${GREEN}"
    echo "    ██████  ██ ████████      ███████ ██    ██ ███    ██  ██████ "
    echo "   ██       ██    ██         ██       ██  ██  ████   ██ ██      "
    echo "   ██   ███ ██    ██    ████ ███████   ████   ██ ██  ██ ██      "
    echo "   ██    ██ ██    ██              ██    ██    ██  ██ ██ ██      "
    echo "    ██████  ██    ██         ███████    ██    ██   ████  ██████ "
    echo -e "${RESET}"
    echo -e "  ${MUTED}─────────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${DIM}${WHITE}  Seamless Git Automation  ${RESET}${DIM}·${RESET}${DIM}${CYAN}  v2.0  ${RESET}"
    echo -e "  ${MUTED}─────────────────────────────────────────────────────────────${RESET}"
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
            echo "ESC"
        else
            echo "SEQ:${seq}"
        fi
    elif [[ "$key" == "" ]]; then
        echo "ENTER"
    elif [[ "$key" == "q" || "$key" == "Q" ]]; then
        echo "QUIT"
    elif [[ "$key" == "1" ]]; then
        echo "1"
    elif [[ "$key" == "2" ]]; then
        echo "2"
    else
        echo "OTHER:${key}"
    fi
}

# ─────────────────────────────────────────────
#  COMMIT MESSAGE INPUT  (styled)
# ─────────────────────────────────────────────
# get commit message from user
function get_commit_message(){
    print_blank
    echo -e "  ${BOLD}${CYAN}Commit Message${RESET}"
    echo -e "  ${MUTED}Leave blank for default → \"Automatic sync commit\"${RESET}"
    print_blank
    printf "  ${ACCENT}❯${RESET}  "
    show_cursor
    # ask user for commit message
    read -r msg
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
        print_warn "No files to add."
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
            tree -L 1 -a --noreport 2>/dev/null | tail -n +2 | while IFS= read -r line; do
                echo -e "     ${DIM}${CYAN}${line}${RESET}"
            done
        else
            echo "     --- Current Directory Files ---"
            printf '%s\n' "${real_files[@]}" | while IFS= read -r f; do
                echo -e "     ${DIM}${CYAN}▸  ${WHITE}${f}${RESET}"
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

    # call commit message getter and store the result
    local result
    result=$(get_commit_message)

    print_blank
    start_spinner "Committing..."
    sleep 0.4
    git commit -m "$result" > /dev/null 2>&1
    stop_spinner

    print_blank
    echo -e "  ${BG_HIGHLIGHT}${BOLD}${WHITE}  ✔  Committed: \"${result}\"  ${RESET}"
    print_blank
    hr
    print_blank
}

# ─────────────────────────────────────────────
#  MENU
# ─────────────────────────────────────────────
draw_menu() {
    draw_banner
    echo -e "  ${BOLD}${WHITE}Select an action${RESET}"
    print_blank
    echo -e "  ${BG_PANEL}${BOLD}${GREEN}  ↵  Run Git-Sync   ${RESET}   ${MUTED}press Enter${RESET}"
    print_blank
    echo -e "  ${DIM}     Exit           ${RESET}   ${MUTED}press Esc or Q${RESET}"
    print_blank
    hr "─" "$MUTED"
    echo -e "  ${MUTED}  ↑↓ navigate  ·  ↵ confirm  ·  Esc/Q quit${RESET}"
    print_blank
}

# main entry of Program
function menu(){
    hide_cursor
    while true; do
        draw_menu
        # read a single keypress (no Enter needed)
        local choice
        choice=$(read_key)

        case "$choice" in
            ENTER|1)
                # run the git helper or Enter
                initializer_helper
                print_blank
                echo -e "  ${MUTED}Press any key to return to menu...${RESET}"
                read_key > /dev/null
                ;;
            ESC|QUIT|2)
                # exit loop with ESC, q, or 2
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