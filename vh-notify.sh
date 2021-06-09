#!/bin/bash

### The script only knows of 6 events that can be parsed from the server console log
### 1. Player joins
### 2. Player disconnects
### 3. Player (re)spawns
### 4. Player dies
### 5. Server booting and loading a world
### 6. Server shutting down
###
### You need to configure CHATID, KEY and LOGFILE
###
### The script will lookup the 64bit Steam ids that connect to the server
### The corresponding Steam name is stored in usernames.txt
### You can add Steam ids and (change) names manually too, the script will not overwrite
### For character death and (re)spawn the Valheim character name is parsed from the log message
### 
### Run this script in the background and/or add it to cron (crontab -e), then 
### @reboot /home/vhserver/valheim-notify/vh-notify.sh &

CHATID=""
KEY=""
LOGFILE="/home/vhserver/log/console/vhserver-console.log"

USERLIST="usernames.txt"
TIMEOUT="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
STEAMURL="https://steamcommunity.com/profiles/"

send(){
	curl -s --max-time $TIMEOUT -d "chat_id=$CHATID&disable_web_page_preview=1&text=$1" $URL > /dev/null
}

addcharname(){
	# attempt to add a player name using their steam id 
	NAME=$(curl -sL --max-time $TIMEOUT $STEAMURL$1 | grep -oPm1 'actual_persona_name">\K(.+)(?=</span>)')
	if [[ $NAME ]]; then
		echo "$1 $NAME" >> $USERLIST
		loadnames
	fi
}

charname(){
	if [ ${USERNAMES[$1]+abc} ]; then
		echo ${USERNAMES[$1]}
	else
		echo "Unknown ($1)"
	fi
}

loadnames(){
	declare -gA USERNAMES
	if ! [[ -r $USERLIST ]]; then
		echo "Warning: cannot find or read $USERLIST"
	else
		while IFS= read -r line; do
			if ! [[ $line == "#"* || $line == "" || $line == " "* ]]; then
				USERNAMES[${line%% *}]=${line#* }
			fi
		done < "$USERLIST"
	fi
}

loadnames

tail -Fn0 $LOGFILE | \
while read line ; do
	echo "$line" | grep -Eq "ZDOID|handshake|Closing|Load world|OnApplicationQuit" 
	if [ $? = 0 ]; then
		
		# store $line in dedicated var as it will unexplainably get reset when a steam id is added
		CLINE=$line
		STEAMID=$(echo "$CLINE" | grep -oP '76[0-9]{10,}')
		if [[ $STEAMID ]] &&  [ ! ${USERNAMES[$STEAMID]+abc} ]; then
			addcharname $STEAMID
			CHARNAME="$(charname ${STEAMID})"

		elif [[ $STEAMID ]]; then
			CHARNAME="$(charname ${STEAMID})"
		
		fi

		if [[ $CLINE == *"handshake"* ]]; then
			send "${CHARNAME} is joining the server"

		elif [[ $CLINE == *"Closing"* ]]; then
			send "$CHARNAME has disconnected from the server"

                elif [[ $line == *"Load world"* ]]; then
                        WORLDNAME=$(echo "$line"| grep -oP 'Load world \K(.+)')
                        echo "Server booted and loaded world $WORLDNAME"

                elif [[ $line == *"OnApplicationQuit"* ]]; then
                        echo "Server is shutting down"

		else
			# Only ZOID options left, if ends with in 0:0 then player died, otherwise spawned
			CHARNAME=$(echo "$CLINE" | grep -oP 'ZDOID from \K(.+)(?= :)')
		
			# line ending match on 0:0 does not seem to work, this does
			if [[ $line == *": 0:"* ]]; then
				send "$CHARNAME has just died"

			else
				send "$CHARNAME has just spawned"
				
			fi
		
		fi
	fi
done
