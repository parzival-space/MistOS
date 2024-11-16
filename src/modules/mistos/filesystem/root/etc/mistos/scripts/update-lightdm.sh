#!/bin/bash
STATE_FILE=/var/lib/userconf-mistos/updated_lightdm_conf

if [ ! -f $STATE_FILE ]; then
    sed -i 's/UID_1000_PLACEHOLDER/'$(id -nu 1000)'/g' /etc/lightdm/lightdm.conf

    mkdir -p $(dirname $STATE_FILE)
    touch $STATE_FILE
fi