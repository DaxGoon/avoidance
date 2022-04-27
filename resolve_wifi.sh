#!/usr/bin/env bash
resolve_wifi() {
    while true; do
        read -p "Do you want to enable WiFi? (y/n) " yn
        case $yn in
	        [yY] ) echo "ok, WiFi will be enabled".;
		           break;;
	        [nN] ) echo "Not enabling wifi";
		           exit;;
	        * ) echo "invalid response";;
        esac
    done
    # get WEP / WPA info
    printf "Which security do you have on your wifi connection? \n"
    select sec in "WEP" "WPA"; do
        printf "Selected security configuration method: %s \n" "$sec"
        return
    done
}
