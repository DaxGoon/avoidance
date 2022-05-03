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
    # Check if root user
	[ ! "$EUID" -eq 0 ] && echo 'The script needs to be run by the root user.' >&2 && exit 1

    # Check hw & update pkg list
    resolve_hw
    case "$arch" in
		"Intel") printf "intel-ucode\nlinux-firmware-intel\nintel-video-accel" >> pkg_file ;;
		"AMD") printf "linux-firmware-amd\nmesa-dri\nxf86-video-amdgpu\mesa-vaapi\mesa-vdpau" >> pkg_file ;;
	esac

    # Check Desktop choice & update pkg list
    resolve_desktop
	case "$de" in
		"Kde Plasma") printf "kde5\nkde5-baseapps" >> pkg_file ;;
        "Gnome") printf "gnome\ngnome-apps\ngdm" >> pkg_file ;;
        "BSPWM") printf "bspwm\nsxhkd\npolybar\ndmenu\npicom\nnitrogen" >> pkg_file ;;
	esac

    # Check editor choice and update the package list
    resolve_editor
	case "$editor" in
		"emacs")  printf "emacs" >> pkg_file ;;
		"vim")  printf "vim" >> pkg_file ;;
		"neovim")  printf "neovim" >> pkg_file ;;
		"Gedit")  printf "gedit" >> pkg_file ;;
		"Kate")  printf "kate5" >> pkg_file ;;
		"VS Code")  printf "vscode" >> pkg_file ;;
    esac

    # enable and setup wifi
    resolve_wifi
    # first unblock hardware, eg. wifi, if blocked
    rfkill unblock all
    # Create wifi config
    read -pr "Enter the Wifi name (ssid) to connect: " ssid
    read -pr "enter the wifi password: " wifipass
    mkdir -p /etc/wpa_supåplicant
    touch /etc/wpa_supplicant/wpa_supplicant.conf

	case "$sec" in
		WPA) wpa_passphrase "$ssid" "$wifipass" >> /etc/wpa_supplicant/wpa_supplicant.conf ;;
		WEP)  printf "\nnetwork={\n ssid=%s\n key_mgmt=NONE\n wep_key0=%s\n wep_tx_keyidx=0\n auth_alg=SHARED }" "$ssid" "$wifipass" >> /etc/wpa_supplicant/wpa_supplicant.conf ;;
	esac

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
    xbps-install -yv void-repo-nonfree
    xbps-install -Suv

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
    	    xbps-install -vy "$line"
        fi
    done <"$pkg_file"

    # start dbus, polkit and elogind services
    ln -sv /etc/sv/{dbus,elogind,polkit,alsa,tlp} /var/service

    # reconfigure, needed to regenerate initramfs
    xbps-reconfigure --force -a

    # update grub
    update-grub

    # remove orphan packages
    xbps-remove -Ooyv

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
