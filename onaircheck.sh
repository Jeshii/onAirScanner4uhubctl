#!/bin/zsh

# Global variables
verbose=0 # Whether or not to print out the varible values each cycle
portNumber=3 # Mine was 3, use uhubcrl to check this number
locationCode="20-4" # Mine was 20-4, use uhubctl to check this number
sleepFor=10 # How many seconds sleep before checking for meetings
hours=8 # How many hours to run the script
quiet=0 # whether or not to supress notifications

while [[ "$#" -gt 0 ]]
do case $1 in
	-p|--port) portNumber="$2"
    shift;;
	-l|--location) locationCode="$2"
    shift;;
	-s|--sleep) sleepFor="$2"
    shift;;
	-h|--hours) hours="$2"
    shift;;
	--help) echo "onAirScanner4uhubctl - https://github.com/Jeshii/onAirScanner4uhubctl
usage: ./onaircheck.sh [--hours|-h <hours to run>][--location|-l <usb device location from uhubctl>][--port|-p <usb port from uhubctl>][--quiet|-q][--sleep|-s <seconds between USB queries>][--verbose|-v][--help][--version]"
	exit;;
	--version) echo "v1.0.2"
	exit;;
	-v|--verbose) verbose=1;;
	-q|--quiet) quiet=1;;
    *) echo "Unknown parameter passed: $1"
    exit 1;;
esac
shift
done

localIP=$(ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}' | head -1)
end=$((SECONDS+(hours*60*60)))

# Functions
function turnOff {
	# Turn off
	uhubctl -a off -l $locationCode -p $portNumber
	if (( ! $quiet ));then
		osascript -e 'display notification "USB Device '$locationCode' Port '$portNumber' turned off." with title "onAirScanner" subtitle "OFF" sound name "Knock"'
	fi
}

function turnOn {
	# Turn on
	uhubctl -a on  -l $locationCode -p $portNumber
	if (( ! $quiet ));then
		osascript -e 'display notification "USB Device '$locationCode' Port '$portNumber' turned on." with title "onAirScanner" subtitle "ON" sound name "Knock"'
	fi
}

function queryState {
	# check state
	echo "$(uhubctl | grep "Port 3" | awk '{print substr($3,2,1)}')"
}

#########################################################################################
#########################################################################################
# Core Script Logic
#########################################################################################
#########################################################################################

# Initial USB state
usbState=$(queryState)

while [ $SECONDS -lt $end ]; do

	# Check for Running Meetings
	zoomMeeting=$(lsof -anP -i4 -sTCP:LISTEN | grep zoom.us | grep ${localIP}:'*')
	microsoftTeams=$(lsof -anP -i4 -sTCP:LISTEN | grep Microsoft | grep ${localIP}:'*')
	ciscoWebEX=$(lsof -anP -i4 -sTCP:LISTEN | grep Meeting)
	slack=$(lsof -anP -i4 -sTCP:LISTEN | grep 'Slack*' | grep 'UDP \*')
	faceTime=$(lsof -anP -i4 -sTCP:LISTEN | grep avconfere | grep ${localIP}:'*')
	discordMeeting=$(lsof -anP -i4 -sTCP:LISTEN | grep Discord | grep 'UDP \*')

	# Verbose output
	if (( $verbose )); then
		cHours=$(($SECONDS / (60 * 60)))
		echo "Device: ${locationCode}"
		echo "Port: ${portNumber}"
		echo "USB State: ${usbState}"
		echo "Running for ${SECONDS} of ${end} seconds (${cHours} of ${hours} hours)."
		echo "Zoom Meeting Status: ${zoomMeeting}"
		echo "Teams Meeting Status: ${microsoftTeams}"
		echo "WebEX Meeting Status: ${ciscoWebEX}"
		echo "Slack Meeting Status: ${slack}"	
		echo "FaceTime Meeting Status: ${faceTime}"	
		echo "Discord Meeting Status: ${discordMeeting}"	
	fi

	# Main check and on/off
	if [[ -n "$zoomMeeting" || -n "$microsoftTeams" || -n "$ciscoWebEX"  || -n "$slack" || -n "$faceTime" || -n "$discordMeeting" ]];then
		if (( ! $usbState )); then
			turnOn
		fi
	else
		if (( $usbState )); then
			turnOff
		fi
	fi

	# Query state for the odd time when the monitor/hub is turned off/on and the new state doesn't match the old state.
	usbState=$(queryState)

	# Wait for some time before looping
	sleep $sleepFor
done

# turn the port on at the end of script run since this is probably the default for the port.
turnOn