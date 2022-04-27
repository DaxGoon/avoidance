#!/usr/bin/env bash

resolve_desktop() {
    printf "Which desktop environment / window manager would you like to install?\n"
    select de in "KDE Plasma" "Gnome" "BSPWM"; do
        printf "Selected Desktop / WM: %s \n" $de
        return
    done
}
