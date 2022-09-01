#!/bin/bash

#get removed IPs from local_settings.py
REMOVED_IPS=$(grep "REMOVED_IPS" /etc/seedbox/sbmanager/settings/local_settings.py | grep -Eo '[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}')

# get users list of removed IP
for ip in $REMOVED_IPS
do
    /etc/seedbox/sbmanager/venv/bin/python /etc/seedbox/sbmanager/manager.py srvinfo | grep $ip
    result=$?
    if [[ "$result" != "0" ]]; then
        echo "    [ALL GOOD] $ip not assigned to any user!"
    else
        echo "    [NOT GOOD] $ip still assigned to some users!"
    fi
done
