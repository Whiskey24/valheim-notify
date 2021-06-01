#!/bin/bash

### The script only knows of 4 events that can be parsed from the server console log
### 1. Player joins
### 2. Player disconnects
### 3. Player (re)spawns
### 4. Player dies
###
### You need to configure CHATID, KEY and LOGFILE
###
### You can add usernames for the 64bit steam ids that connect in usernames.txt
### Lookup of Steam IDs is done for connect and disconnect messages
### For character death and (re)spawn the username is parsed from the log message
### 
### Run this script in the background and/or add it to cron (crontab -e), then 
### @reboot /home/vhserver/valheim-notify/vh-notify.sh &

CHATID=""
KEY=""
LOGFILE="/home/vhserver/log/console/vhserver-console.log"

USERLIST="usernames.txt"
TIMEOUT="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
USERLIST="usernames.txt"

send(){
	curl -s --max-time $TIMEOUT -d "chat_id=$CHATID&disable_web_page_preview=1&text=$1" $URL > /dev/null
}


charname(){
	if [ ${USERNAMES[$1]+abc} ]; then
		echo ${USERNAMES[$1]}
	else
		echo "Unknown ($1)"
	fi
}


declare -A USERNAMES

if ! [[ -r $USERLIST ]]; then
	echo "Warning: cannot find or read $USERLIST"
else
	while IFS= read -r line; do
		if ! [[ $line == "#"* || $line == "" || $line == " "* ]]; then
			USERNAMES[${line%% *}]=${line#* }
		fi
	done < "$USERLIST"
fi

tail -Fn0 $LOGFILE | \
while read line ; do
	echo "$line" | grep -Eq "ZDOID|handshake|Closing" 
	if [ $? = 0 ]; then

		STEAMID=$(echo "$line" | grep -oP '[0-9]{10,}')
		CHARNAME="$(charname ${STEAMID})"

		if [[ $line == *"handshake"* ]]; then
			send "${CHARNAME} is joining the server"

		elif [[ $line == *"Closing"* ]]; then
			send "$CHARNAME has disconnected from the server"

		else
			# Only ZOID options left, if ends with in 0:0 then player died, otherwise spawned
			CHARNAME=$(echo "$line" | grep -oP 'ZDOID from \K(.+)(?= :)')
		
			if [[ $line == *"0:0" ]]; then
				send "$CHARNAME has just died"

			else
				send "$CHARNAME has just spawned"
				
			fi
		
		fi
	fi
done
