#!/bin/bash

# Enable exit on non 0
set -e

# This script must be run with super user previleges
check_root_perms() {
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
}

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

# PROMPT
printf "This will install the following packages in order to configure the system:\n"
for pkg in "${pkg_list[@]}"; do
    printf "%s " "$pkg"
done

ask_perms() {
    while true; do
        read -pr "Continue?" yn
        case $yn in
            [Yy]* ) make install; break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}


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
    echo #!/bin/bash > "$HOME"/.config/polybar/launch.sh
    echo # Terminate already running bar instances >> "$HOME"/.config/polybar/launch.sh
    echo killall -q polybar >> "$HOME"/.config/polybar/launch.sh
    echo # If all your bars have ipc enabled, you can also use >> "$HOME"/.config/polybar/launch.sh
    echo # polybar-msg cmd quit >> "$HOME"/.config/polybar/launch.sh
    echo # Launch Polybar, using default config location ~/.config/polybar/config.ini >> "$HOME"/.config/polybar/launch.sh
    echo polybar mybar 2>&1 | tee -a /tmp/polybar.log & disown >> "$HOME"/.config/polybar/launch.sh
    echo 'echo "Polybar launched..."' >> "$HOME"/.config/polybar/launch.sh
    # Install configuration for the user
    install -Dm644 /usr/share/examples/polybar/config.ini ~/.config/polybar/config.ini
}


configure_bspwm() {
    # copy configs
    install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
    install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc
    echo "$HOME/.config/polybar/launch.sh" >> "$HOME"/.config/bspwm/bspwmrc
}

update_grub() {
    sudo update-grub
}

remove_orphaned_pkgs() {
    sudo xbps-remove -Ooyv
}


main() {
    ask_perms
    check_root_perms
    enable_wifi
    enable_non_free
    install_pkgs pkg_list
    start_basic_services
    regenerate_initramfs
    setup_polybar
    configure_bspwm
    update_grub
    remove_orphaned_pkgs
}

main
