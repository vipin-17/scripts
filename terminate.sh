#!/bin/bash
# Script to terminate users

function sbterminate() { /etc/seedbox/sbmanager/venv/bin/python /etc/seedbox/sbmanager/user.py --json del $1; }

read -p "Submit the list of Usernames for termination: `echo $'\n>'`" input

for i in ${input[@]}
do
    USERN=$(ls /etc/seedbox/user/ | grep "$i")
    if [[ "$USERN" == "$i" ]]; then
    echo "User for termination:" $i
    sbterminate $i
    
    fi

done
