#!/bin/bash

# create .gitignore file with common patterns
function gitignore_creator_helper(){
    if [ ! -f ".gitignore" ]; then
        echo "Creating .gitignore file..."
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
        echo ".gitignore created successfully."
    else
        echo ".gitignore already exists, skipping."
    fi
}

# get commit message from user
function get_commit_message(){
    # ask user for commit message
    read -p "Write your commit message: " msg
    echo "${msg:-Automatic sync commit}"
}

# git process helper
function initializer_helper(){

    local checker=1  # initialize checker

    if [ -d ".git" ]; then
        echo "git already exists"
        checker=-1
    else
        echo "git does not exist"
        checker=0

        # Initialize git in project root
        git init
        
        # call gitignore creator after init
        gitignore_creator_helper
    fi

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
        echo "No files to add."
    elif [[ "$f_counter" -eq 1 ]]; then
        echo "One file found. Adding it."
        git add "${real_files[0]}"
    else
        echo "Multiple files found. Showing tree structure:"
        # Show the current directory structure as a tree before adding
        if command -v tree >/dev/null 2>&1; then
            tree -L 1 -a
        else
            echo "--- Current Directory Files ---"
            printf '%s\n' "${real_files[@]}"
        fi

        echo "Adding all files..."
        git add .
    fi

    # call commit message getter and store the result
    local result
    result=$(get_commit_message)
    git commit -m "$result"
}

# main entry of Program
function menu(){
    while true; do
        echo "===================="
        echo "Git-Sync Menu"
        echo "1) Run Git-Sync"
        echo "2) Exit"
        read -p "Choose an option [1]: " choice

        case "$choice" in
            1|"") 
                initializer_helper ;;  # run the git helper or Enter
            2|[eE][xX][iI][tT]|"q"|"Q") 
                echo "Exiting..."; break ;;  # exit loop with 2, exit, or q
            *) 
                echo "Invalid choice, try again." ;;  # invalid input
        esac
    done
}

# start the program
menu