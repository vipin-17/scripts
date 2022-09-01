#!/bin/bash

#get removed IPs from local_settings.py
REMOVED_IPS=$(grep "REMOVED_IPS" /etc/seedbox/sbmanager/settings/local_settings.py | grep -Eo '[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}')

# get users list of removed IP
for ip in $REMOVED_IPS
do
    echo "FIXING USERS with $ip"
    USERS_LIST=$(/etc/seedbox/sbmanager/venv/bin/python /etc/seedbox/sbmanager/manager.py devexec ip-info | grep $ip | grep -Eo '\b[a-z][a-z0-9]{1,30}')
    for USER in $USERS_LIST
    do
        if id -u "$USER" >/dev/null 2>&1; then
            echo "  [FIXING] $USER"
            #fix removed IP for user
            /etc/seedbox/sbmanager/venv/bin/python /etc/seedbox/sbmanager/user.py modify --ip= $USER >/dev/null 2>&1
            echo "    NULL removed_IP for $USER"
            /etc/seedbox/sbmanager/venv/bin/python /etc/seedbox/sbmanager/user.py modify $USER >/dev/null 2>&1
            echo "    [DONE] New IP for $USER"

            # fix removed IP within user's Apps
            USERSHELL=$(getent passwd "$USER" | awk -F: '{print $NF}')
            if [[ "$USERSHELL" == "/bin/bash" ]]; then
            #fix Deluge if installed
                su - "$USER" -c 'bash -c "cd; source .profile; if [[ -L bin/deluge && -d .config/deluge ]]; then echo '"'"'     Fixing Deluge...'"'"'; app-deluge restart; app-deluge repair 1>/dev/null; fi"'
            #fix AutoDL if installed
                su - "$USER" -c 'bash -c "cd; source .profile; if [[ -d .autodl && -d .irssi ]]; then echo '"'"'     Fixing AutoDL...'"'"'; app-autodl-irssi restart 1>/dev/null; fi"'
            # fix Qbittorrent if installed
                su - "$USER" -c 'bash -c "cd; source .profile; if [[ -L bin/qbittorrent-nox && -d .config/qBittorrent ]]; then echo '"'"'     Fixing qBittorrent...'"'"'; app-qbittorrent ip 1>/dev/null; fi"'
                printf "  FIXED IP for $USER\n\n"
            else
                printf "  FIXED IP for $USER but SUSPENDED\n\n"
            fi
        else
            echo "  [INVALID] $USER"
        fi
    done
done
