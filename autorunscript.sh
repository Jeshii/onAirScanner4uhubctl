#!/bin/zsh

# Global variables
portNumber="3" #mine was 3
localIP=$(ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}' | head -1)


# Running Meetings
zoomMeeting=$(lsof -anP -i4 -sTCP:LISTEN | grep zoom.us)
microsoftTeams=$(lsof -anP -i4 -sTCP:LISTEN | grep Microsoft | grep ${localIP}:'*')
ciscoWebEX=$(lsof -anP -i4 -sTCP:LISTEN | grep Meeting)
slack=$(lsof -anP -i4 -sTCP:LISTEN | grep 'Slack*')
faceTime=$(lsof -anP -i4 -sTCP:LISTEN | grep avconfere)

# API Functions
function turnOff {
	# Turn Off
	uhubctl -a off -p $portNumber
}

function turnOn {
	# Turn on
	uhubctl -a on -p $portNumber
}


#########################################################################################
#########################################################################################
# Core Script Logic
#########################################################################################
#########################################################################################

if [[ -n "$zoomMeeting" || -n "$microsoftTeams" || -n "$ciscoWebEX"  || -n "$slack" || -n "$faceTime" ]];then
	echo "Meeting running"
	turnOn
	else
	echo "There is no meeting running"
	turnOff
fi

sleep 10
