#!/bin/bash
# Script to terminate users

function sbterminate() { /etc/seedbox/sbmanager/venv/bin/python /etc/seedbox/sbmanager/user.py --json del $1 --days=0; }

read -p "Submit the list of Usernames for termination: `echo $'\n>'`" input

for i in ${input[@]}
do
    USERN=$(ls /etc/seedbox/user/ | grep "$i")
    if [[ "$USERN" == "$i" ]]; then
        if id -u "$USERN" 2>&1 > /dev/null; then
            printf "[+] User for termination: $i ...\n\n"
            sbterminate $i
        else
            printf "[-] USER NOT VALID !!!\n\n"
        fi
    fi

done
