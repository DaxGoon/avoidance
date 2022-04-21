#!/bin/bash

# Enable exit on non 0
set -e
set -o xctrace
set -o errexit
set -o nounset
set -o pipefail
set -o nullglob

pkg_list=(
    xorg-minimal
    xterm
    xorg-fonts
    libX11
    libXext
    libXrender
    xrandr
    arandr
    xtools
    base-devel
    libX11-devel
    libXft-devel
    libXinerama-devel
    harfbuzz-devel
    freetype-devel
    fontconfig-devel
    elogind
    dbus-elogind
    dbus-elogind-libs
    dbus-elogind-x11
    polkit
    intel-ucode
    linux-firmware-intel
    intel-video-accel
    xf86-input-synaptics
    dmenu
    nitrogen
    picom
    ranger
    emacs
    git
    rsync
    alsa-utils
    apulse
    st
    urxvt
    bspwm
    sxhkd
    polybar
)

install_pkgs() {
    if xbps-query "$1" &> /dev/null; then
	    tput setaf 2
  	    printf 'The package %s is already installed \n' "$1"
	    tput sgr0
	else
    	tput setaf 3
    	printf 'Installing package: %s \n' "$1"
    	tput sgr0
    	sudo xbps-install -vy "$1"
    fi
}

enable_wifi() {
    # first unblock hardware, eg. wifi, if blocked
    rfkill unblock all
    # Create wifi config
    read -pr "Enter the Wifi name (ssid) to connect: " ssid
    read -pr "enter the wifi password: " wifipass
    touch /etc/wpa_supplicant/wpa_supplicant.conf
    wpa_passphrase "$ssid" "$wifipass" >> /etc/wpa_supplicant/wpa_supplicant.conf
    printf "\nnetwork={\n ssid=%s\n key_mgmt=NONE\n wep_key0=%s\n wep_tx_keyidx=0\n auth_alg=SHARED }" "$ssid" "$wifipass">> /etc/wpa_supplicant/wpa_supplicant.conf
    # enable wifi service
    ln -s /etc/sv/wpa_supplicant /var/service/
    # rerun service if it does not automatically
    sv up wpa_supplicant
}

enable_non_free() {
    # enable void non-free repo & update the system
    printf 'Updating System ... \n'
    cd "$HOME"
    git clone git://github.com/void-linux/void-packages.git
    cd void-packages
    ./xbps-src binary-bootstrap
    ./xbps-src bootstrap-update
    sudo xbps-install -yv void-repo-nonfree
    sudo xbps-install -Suv
}

start_basic_services() {
    # start dbus, polkit and elogind services
    ln -sv /etc/sv/{dbus,elogind,polkit,alsa,tlp} /var/service
}

regenerate_initramfs() {
    # reconfigure, needed to regenerate initramfs to include microcode
    xbps-reconfigure --force -a
}

setup_polybar() {
    # create launch script
    mkdir -p "$HOME"/.config/polybar && touch "$HOME"/.config/polybar/launch.sh
    printf "\n#!/bin/bash \n# Terminate already running bar instances \nkillall -q polybar \n# If all your bars have ipc enabled, you can also use \n# polybar-msg cmd quit \n# Launch Polybar, using default config location ~/.config/polybar/config.ini \npolybar mybar 2>&1 | tee -a /tmp/polybar.log & disown" >> "$HOME"/.config/polybar/launch.sh
    # Install configuration for the user
    install -Dm644 /usr/share/examples/polybar/config.ini ~/.config/polybar/config.ini
}


configure_bspwm() {
    # copy configs
    install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
    install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc
    echo "$HOME/.config/polybar/launch.sh" >> "$HOME"/.config/bspwm/bspwmrc
}

enable_touchpad() {
    [ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf '\nSection "InputClass"
        \nIdentifier "libinput touchpad catchall"
        \nMatchIsTouchpad "on"
        \nMatchDevicePath "/dev/input/event*"
        \nDriver "libinput"
	    \nOption "Tapping" "on"
        \nEndSection' > /etc/X11/xorg.conf.d/40-libinput.conf
}

update_grub() {
    sudo update-grub
}

remove_orphaned_pkgs() {
    sudo xbps-remove -Ooyv
}


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

    # Give info
    printf "This will install the following packages in order to configure the system:\n"
    for pkg in "${pkg_list[@]}"; do
        printf "%s " "$pkg"
    done
    # Prompt for confirmation
    while true; do
        read -pr "Continue?" yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    # Execute main tasks
    printf "Enabling wifi [1/10]\n"
    enable_wifi
    printf "Enabling non-free repository [2/10]\n"
    enable_non_free
    printf "Installing required packages [3/10]\n"
    install_pkgs pkg_list
    printf "Enabling and starting basic services [4/10]\n"
    start_basic_services
    printf "Regenerating initramfs [5/10]\n"
    regenerate_initramfs
    printf "Setting up Polybar [6/10]\n"
    setup_polybar
    printf "Enabling Configuring BSPWM window manager [7/10]\n"
    configure_bspwm
    printf "Enabling touchpad [8/10]\n"
    enable_touchpad
    printf "Updating grub [9/10]\n"
    update_grub
    printf "Removing orphaned packages [10/10]\n"
    remove_orphaned_pkgs
    printf "Congratulations! All Done 👌\n✨✨✨"
}

main
