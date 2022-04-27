#!/usr/bin/env bash
resolve_editor() {
    printf "Which text editor you prefer? \n"
    select editor in "emacs" "nano" "vim" "GEdit" "Kate" "VS Code" "Do not know"; do
        printf "Selected text editor: %s \n" "$editor"
        return
    done
}
