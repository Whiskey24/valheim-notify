# Valheim Notify

Valheim Notify is a simple bash script that sends server notifications to a telegram chat. It is aimed to be simple to use and should run on most Linux flavours.

## Supported notifications
The script only knows of 8 events that can be parsed from the server console log:
1. Player joins the server
2. Player disconnects from the server
3. Player (re)spawns
4. Player dies
5. All online players take some zzz's in the night and a new day begins (server skips the remaining night time)
6. A random event is triggered, see https://valheim.fandom.com/wiki/Events 
7. Server booting and loading a world
8. Server shutting down

## Telegram prerequisites
You need to create a Telegram bot, add it to a chat and retrieve the ID of the chat.
- Create a Telegram bot, see [these instructions](https://core.telegram.org/bots#6-botfather) and copy the API token
- Add the bot to a chat in Telegram
- In a browser, open this page ``https://api.telegram.org/bot<API-token>/getUpdates`` and note the chat ID

## Installation & configuration

- Place the scripts vh-notify.sh and userlist.txt on your server 
- In the vh-notify.sh script, configure these values
  - CHATID: the ID of the Telegram chat that the notifications will be sent to
  - KEY: the API token of your Telegram bot
  - LOGFILE: the location of your Valheim server console log
- Make sure vh-notify.sh is executable, e.g. do ``chmod +x vh-notify.sh``
- ~~Add the 64-bit Steam IDs with corresponding usernames to usernames.txt~~ No longer needed, the script will attempt to lookup the IDs and the usernames. But if you like you can change the names or add IDs and names, the script will not overwrite existing data in this file.
- Start the script with ``./vh-notify.sh &``
- To start automatically on boot, add to cron with ``crontab -e`` and then add a line (replace with actual location of the script) ``@reboot /home/vhserver/valheim-notify/vh-notify.sh &``

## Steam usernames
The connect and disconnect messages in the server log mention the 64bit Steam ID of the player that connects to the server. The script will attempt to lookup the Steam ID and store the ID with username in usernames.txt. If the script cannot find a matching Steam ID in usernames.txt, it will report ``Unknown (Steam ID)`` in the notification.

The death and (re)spawn messages in the log mention the Valheim character name that the player entered the world with, so the script parses these from the log directly.
