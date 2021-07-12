#!/bin/bash

### The script only knows of 8 events that can be parsed from the server console log
### 1. Player joins
### 2. Player disconnects
### 3. Player (re)spawns
### 4. Player dies
### 5. All online players take some zzz's in the night and a new day begins
### 6. A random event is triggered, see https://valheim.fandom.com/wiki/Events
### 7. Server booting and loading a world
### 8. Server shutting down
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
VALHEIMVERSION="Not set"

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

eventmessage(){
    case $1 in
    
        "army_eikthyr")
            echo $'Eikthyr rallies the creatures of the forest.\nA 1:30 minute raid of Boars and Necks.'
            ;;
            
        "army_theelder")
            echo $'The forest is moving...\nA 2 minute raid of Greydwarfs, Greydwarf brutes and Greydwarf shamans'
            ;;
            
        "army_bonemass")
            echo $'A foul smell from the swamp\nA 2:30 minute raid of Draugr and Skeletons'
            ;;
        
        "army_moder")
            echo $'A cold wind blows from the mountains\nA 2:30 minute raid of Drakes and Freezing on the area'
            ;;
        
        "army_goblin")
            echo $'The horde is attacking\nA 2 minute raid of Fulings, Fuling Berserkers and Fuling shamans'
            ;;
        
        "foresttrolls")
            echo $'The ground is shaking\nA 1:20 minute raid of Trolls'
            ;;
            
        "blobs")
            echo $'A foul smell from the swamp\nA 2 minute raid of Blobs and Oozers'
            ;;
        
        "skeletons")
            echo $'Skeleton Surprise\nA 2 minute raid of Skeletons and Rancid remains'
            ;;
            
        "surtlings")
            echo $'There\'s a smell of sulfur in the air\nA 2 minute raid of Surtlings'
            ;;
                    
        "wolves")
            echo $'You are being hunted\nA 2 minute raid of Wolves'
            ;;
        
        *)
            echo -e "Unknown event!\n$1"
            ;;

    esac
}

loadnames

tail -Fqn0 $LOGFILE | \
while read line ; do
    echo "$line" | grep -Eq "ZDOID|handshake|Closing|day:|Load world|OnApplicationQuit|Random event|Valheim version"
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
            WORLDNAME=$(echo "$line" | grep -oP 'Load world \K(.+)')
	    send "Server booted (version $VALHEIMVERSION) and loaded world $WORLDNAME"

        elif [[ $line == *"day:"* ]]; then
            DAY=$(echo "$line" | grep -oP 'day:\K(\d+)')
	    DAY=$(($DAY + 1))
            send "All players sleep through the night. It is now day $DAY"

        elif [[ $line == *"OnApplicationQuit"* ]]; then
            send "Server is shutting down"

        elif [[ $CLINE == *"Random event"* ]]; then
            EVENT=$(echo "$line" | grep -oP 'Random event set:\K([0-9a-zA-Z_]+)')
            EVENTMSG="$(eventmessage ${EVENT})"
            send $'Random event triggered!\n'"$EVENTMSG"

        elif [[ $CLINE == *"Valheim version"* ]]; then
            VALHEIMVERSION=$(echo "$line" | grep -oP 'Valheim version:\K(.+)')
        
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

