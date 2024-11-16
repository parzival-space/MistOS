#!/bin/bash
STATE_FILE=/var/lib/userconf-mistos/enabled_gpu

if [ ! -f $STATE_FILE ]; then
    sed -i '1s/$/ quiet splash disable_splash=1 plymouth.ignore-serial-consoles/' /boot/firmware/cmdline.txt

    check="$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}' | sed -e 's/[a-c]//')"
    if [ "${check}" != "03111" ] && [ "${check}" != "03112" ]; then
        sed -i /boot/firmware/config.txt -e "s/^\#dtoverlay=vc4-kms-v3d/dtoverlay=vc4-kms-v3d/"
        printf "dtoverlay=vc4-kms-v3d\n" | tee -a /boot/firmware/config.txt
    fi
    sed -i /boot/firmware/config.txt -e "s/^gpu_mem/\#gpu_mem/"

    mkdir -p $(dirname $STATE_FILE)
    touch $STATE_FILE
    shutdown -r now
fi