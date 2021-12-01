#!/bin/bash
# Script to Adjust Traffic as requested

#Set the Traffic amount first
read -p "Traffic Amount: " input
TRAFFIC_AMNT=""$input"000511627776"

echo "Entered Traffic in bytes" $TRAFFIC_AMNT

#Proceed with Adjustment now
function TRAFFIC_FIX() { /etc/seedbox/sbmanager/venv/bin/python /etc/seedbox/sbmanager/user.py modify --max-traffic=$TRAFFIC_AMNT $1; }

echo
read -p "Enter the Usernames for adjustment now: `echo $'\n>'`" input

for i in ${input[@]}
do
    USERN=$(ls /etc/seedbox/user/ | grep "$i")
    if [[ "$USERN" == "$i" ]]; then
    TRAFFIC_FIX $i >/dev/null 2>&1
    echo "[ADJUSTMENT DONE]:"  $i $TRAFFIC_AMNT >> /root/traffic-adjustment.txt

    else
     echo "[USER NOT VALID]:" $i
    fi

done
