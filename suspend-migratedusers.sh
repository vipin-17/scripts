#!/bin/bash
# Script to suspend users

function sbsuspend() { /etc/seedbox/sbmanager/venv/bin/python /etc/seedbox/sbmanager/user.py --json suspend $1; }

read -p "Submit the list of Usernames with  Host for suspension: `echo $'\n>'`" input

for i in ${input[@]}
do
    USERN=$(ls /etc/seedbox/user/ | grep "$i")
    if [[ "$USERN" == "$i" ]]; then
    echo "User for suspension:" $i
    sbsuspend $i >/dev/null 2>&1

    echo "[SUSPENDED]:"  $i

    else
     echo "[USER NOT VALID]:" $i
    fi

done
