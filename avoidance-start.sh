#!/bin/bash

# Enable good debugging options
set -e
set -o xctrace
set -o errexit
set -o nounset
set -o pipefail
set -o nullglob

# get utils
# shellcheck source=./resolve_hw.sh
# shellcheck source=./resolve_desktop.sh
# shellcheck source=./resolve_editor.sh
source resolve_hw.sh
source resolve_desktop.sh
source resolve_editor.sh
source resolve_wifi.sh
pkg_file="pkgs.txt"

main() {
    # Check su perms
    if ! [ "$(id -u)" = 0 ]; then
        printf 'The script needs to be run as root.\n' >&2
        exit 1
    fi
    if [ "$SUDO_USER" ]; then
        real_user=$SUDO_USER
    else
        real_user=$(whoami)
    fi
    printf 'Running the program as %s \n' "$real_user"

    # Check hw & update pkg list
    resolve_hw
    if [ "$arch" = "Intel" ]; then
        printf "intel-ucode\nlinux-firmware-intel\nintel-video-accel" >> pkg_file
    fi
    if [ "$arch" = "AMD" ]; then
        printf "linux-firmware-amd\nmesa-dri\nxf86-video-amdgpu\mesa-vaapi\mesa-vdpau" >> pkg_file
    fi

    # Check Desktop choice & update pkg list
    resolve_desktop
    if [ "$de" = "KDE Plasma" ]; then
        printf "kde5\nkde5-baseapps" >> pkg_file
    fi
    if [ "$de" = "Gnome"  ]; then
        printf "gnome\ngnome-apps\ngdm" >> pkg_file
    fi
    if [ "$de" = "BSPWM"  ]; then
        printf "bspwm\nsxhkd\npolybar\ndmenu\npicom\nnitrogen" >> pkg_file
    fi

    # Check editor choice and update the package list
    resolve_editor
    if [ "$editor" = "emacs" ]; then
        printf "emacs" >> pkg_file
    fi
    if [ "$editor" = "nano"  ]; then
        printf "nano" >> pkg_file
    fi
    if [ "$editor" = "vim"  ]; then
        printf "vim" >> pkg_file
    fi
    if [ "$editor" = "GEdit" ]; then
        printf "gedit" >> pkg_file
    fi
    if [ "$editor" = "Kate"  ]; then
        printf "kate5" >> pkg_file
    fi
    if [ "$editor" = "VS Code"  ]; then
        printf "vscode" >> pkg_file
    fi

    # enable and setup wifi
    resolve_wifi
    # first unblock hardware, eg. wifi, if blocked
    rfkill unblock all
    # Create wifi config
    read -pr "Enter the Wifi name (ssid) to connect: " ssid
    read -pr "enter the wifi password: " wifipass
    mkdir -p /etc/wpa_supåplicant
    touch /etc/wpa_supplicant/wpa_supplicant.conf

    if [ "$sec" = "WPA" ]; then
        wpa_passphrase "$ssid" "$wifipass" >> /etc/wpa_supplicant/wpa_supplicant.conf
    fi
    if [ "$sec" = "WEP" ]; then
        printf "\nnetwork={\n ssid=%s\n key_mgmt=NONE\n wep_key0=%s\n wep_tx_keyidx=0\n auth_alg=SHARED }" "$ssid" "$wifipass">> /etc/wpa_supplicant/wpa_supplicant.conf
    fi
    # enable wifi service
    ln -s /etc/sv/wpa_supplicant /var/service/
    # rerun service if it does not automatically
    sv up wpa_supplicant

    # enable non-free repo
    # enable void non-free repo & update the system
    printf 'Enabling non-free repository ... \n'
    cd "$HOME"
    git clone git://github.com/void-linux/void-packages.git
    cd void-packages
    ./xbps-src binary-bootstrap
    ./xbps-src bootstrap-update
    sudo xbps-install -yv void-repo-nonfree
    sudo xbps-install -Suv

    # Give pkg installation info before installing packages
    printf "This will install the following packages in order to configure the system:\n"
    while read -r line; do
        printf "%s " "$line"
    done <"$pkg_file"
    # Prompt for confirmation
    while true; do
        read -pr "Continue?" yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) printf "Please answer yes or no.\n";;
        esac
    done

    # install packages
    printf "\n" >> pkg_file
    while read -r line; do
        if xbps-query "$line" &> /dev/null; then
	        tput setaf 2
  	        printf 'The package %s is already installed \n' "$1"
	        tput sgr0
	    else
    	    tput setaf 3
    	    printf 'Installing package: %s \n' "$1"
    	    tput sgr0
    	    sudo xbps-install -vy "$line"
        fi
    done <"$pkg_file"

    # start dbus, polkit and elogind services
    ln -sv /etc/sv/{dbus,elogind,polkit,alsa,tlp} /var/service

    # reconfigure, needed to regenerate initramfs
    xbps-reconfigure --force -a

    # update grub
    sudo update-grub

    # remove orphan packages
    sudo xbps-remove -Ooyv

    # If the desktop / wm is BSPWM
    if [ "$de" = "BSPWM" ]; then
        # setup polybar
        mkdir -p "$HOME"/.config/polybar && touch "$HOME"/.config/polybar/launch.sh
        printf "\n#!/bin/bash \n# Terminate already running bar instances \nkillall -q polybar \n# If all your bars have ipc enabled, you can also use \n# polybar-msg cmd quit \n# Launch Polybar, using default config location ~/.config/polybar/config.ini \npolybar mybar 2>&1 | tee -a /tmp/polybar.log & disown" >> "$HOME"/.config/polybar/launch.sh
        # Install configuration for the user
        install -Dm644 /usr/share/examples/polybar/config.ini ~/.config/polybar/config.ini

        # setup BSPWM config
        # copy configs
        install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
        install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc
        printf "%s/.config/polybar/launch.sh" "$HOME">> ~/.config/bspwm/bspwmrc
    fi

    # finally enable touchpad
    mkdir -p /etc/X11/xorg.conf.d && touch /etc/X11/xorg.conf.d/40-libinput.conf
    [ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf '\nSection "InputClass" \nIdentifier "libinput touchpad catchall" \nMatchIsTouchpad "on" \nMatchDevicePath "/dev/input/event*" \nDriver "libinput" \nOption "Tapping" "on" \nEndSection' > /etc/X11/xorg.conf.d/40-libinput.conf

    printf "Congratulations! All Done 👌\n✨✨✨"
}

main "$@"
