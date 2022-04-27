#!/usr/bin/env bash
# get hardware architecture from user, eg. Intel or AMD
resolve_hw() {
    printf "Please select what hardware (eg. CPU etc.) you have? (enter the number...)\n"
    select arch in "Intel" "AMD" "Do not know"; do
        printf "Selected hardware: %s \n" "$arch"
        return
    done
}

# resolve_hw
# printf $arch
