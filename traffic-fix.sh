#!/bin/bash
# Script to Adjust Traffic as requested

#Set the Traffic amount first
read -p "Traffic Amount: `echo $`" input
TRAFFIC_AMNT="'$1'000511627776"

echo "Checked Entered Traffic" $TRAFFIC_AMNT


#function TRAFFIC_FIX() { /etc/seedbox/sbmanager/venv/bin/python /etc/seedbox/sbmanager/user.py modify --max-traffic=$1 $2; }

#read -p "Enter the Usernames with  Traffic Amount for adjustment: `echo $'\n>'`" input

#for i in ${input[@]}
#do
#    USERN=$(ls /etc/seedbox/user/ | grep "$i")
#    if [[ "$USERN" == "$i" ]]; then
 #   echo "User for suspension:" $i
  #  sbsuspend $i >/dev/null 2>&1
#   echo "[SUSPENDED]:"  $i

 #   else
  #   echo "[USER NOT VALID]:" $i
   # fi

#done
