
# onAirScanner4uhubctl

This is a modification of the [onAirScanner](https://github.com/mvdbent/onAirScanner) script that instead of using Hue lightbulbs, it just uses uhubctl to turn USB ports on or off.

While working from home, we all have a lot of meetings, and sometimes a family member or a roommate has no idea that you are in a meeting and they walk into the room without even a knock.

Setting up a light to show when you are "ON AIR" or in a meeting is a great solution.
There are several solutions out on the internet that can do this. Still, a lot of these solutions connect to your calendar via [IFTTT](https://ifttt.com) or [Zapier](https://zapier.com/) and then you need to create an action with homekit or homebridge to turn on a light with the colour red when in a meeting and green when it is safe to enter.
Another straightforward way is to buy a button that turns a light on or off. (The trick is to try not to forget to push the button, it is easy to forget)

Also, another challenge is that I am using multiple meeting applications (Zoom, WebEx, Microsoft Teams, Slack, etc.), and each application has its way of doing things.

Here we have a script that monitors your mac for an active online meeting.

(**When the camera and mic are on!! As in full active participation, not just listing in**) 

**Example**
```bash
./autorunscript.sh --sleep 1 --location "20-4" --hours 1 --port 3 --verbose
```

## uhubctl
Go visit [uhubctl](https://github.com/mvp/uhubctl) to get that set up. It is needed to turn on and off USB ports. There is also a list of know working USB hubs that support it, but my Dell monitor just happened to work even though it wasn't on the list.

## Scan for any Running Meetings
### The Challenge

_"How do we know when we are in a meeting"_ (even when we have turned off the Camera and/or mic)

Our options are:
- We could look for running process, but this doesn't mean you are in a meeting.
- Hook our calendar up to a 3rd party service (can't do that)

The only thing that seems to be content and reliable is if there is an open connection.

Running `lsof` (List open files) command without any options will list all open files of your system that belongs to all active process.
This process takes a while and you will get a full list of everything, but we don't need all this information.

We are going to narrow this down to only internet related connections by adding `-i` to the command.

**Example**
```bash
lsof -i | grep zoom
zoom.us   53231 mvdbent   26u  IPv4 0x64763030ad598a1d      0t0  TCP 10.0.1.116:60144->ec2-3-235-72-248.compute-1.amazonaws.com:https (ESTABLISHED)
zoom.us   53231 mvdbent   48u  IPv4 0x64763030acb3165d      0t0  TCP 10.0.1.116:63973->ec2-52-202-62-196.compute-1.amazonaws.com:https (ESTABLISHED)
zoom.us   53231 mvdbent   51u  IPv4 0x64763030adc2b03d      0t0  TCP 10.0.1.116:55830->ec2-3-235-96-204.compute-1.amazonaws.com:https (ESTABLISHED)
zoom.us   53231 mvdbent   56u  IPv4 0x64763030a88c4c7d      0t0  TCP 10.0.1.116:63978->149.137.8.183:https (ESTABLISHED)
```
We now add the following options to the `lsof` command:
- **-a** option ( can be used to ANDed the selections)
- **-n** (inhibits the conversion of network numbers to host names for network files)
- **-P** (inhibits the conversion of port numbers to port names for network files)
We want to inhibit the output so `lsof` can give us results **faster**.

**Example**
```bash
lsof -anP -i | grep zoom
zoom.us   53231 mvdbent   26u  IPv4 0x64763030ad598a1d      0t0  TCP 10.0.1.116:60144->3.235.72.248:https (ESTABLISHED)
zoom.us   53231 mvdbent   48u  IPv4 0x64763030acb3165d      0t0  TCP 10.0.1.116:63973->52.202.62.196:https (ESTABLISHED)
zoom.us   53231 mvdbent   51u  IPv4 0x64763030adc2b03d      0t0  TCP 10.0.1.116:55830->3.235.96.204:https (ESTABLISHED)
zoom.us   53231 mvdbent   56u  IPv4 0x64763030a88c4c7d      0t0  TCP 10.0.1.116:63978->149.137.8.183:https (ESTABLISHED)
```

Now we found the active process that have a internet related connection, this still doesn't mean that we are in a meeting.
This means that the Zoom.us app is opend and logged in with your account.
After starting a meeting in zoom, we got extra connections based on UDP added.

**Example**
```bash
lsof -anP -i | grep zoom
zoom.us   53231 mvdbent   26u  IPv4 0x64763030ad598a1d      0t0  TCP 10.0.1.116:60144->3.235.72.248:https (ESTABLISHED)
zoom.us   53231 mvdbent   48u  IPv4 0x64763030acb3165d      0t0  TCP 10.0.1.116:63973->52.202.62.196:https (ESTABLISHED)
zoom.us   53231 mvdbent   51u  IPv4 0x64763030adc2b03d      0t0  TCP 10.0.1.116:55830->3.235.96.204:https (ESTABLISHED)
zoom.us   53231 mvdbent   56u  IPv4 0x64763030a88c4c7d      0t0  TCP 10.0.1.116:63978->149.137.8.183:https (ESTABLISHED)
zoom.us   53231 mvdbent   60u  IPv4 0x64763030846e819d      0t0  UDP 10.0.1.116:63026
zoom.us   53231 mvdbent   61u  IPv4 0x64763030846e8d3d      0t0  UDP 10.0.1.116:58615
zoom.us   53231 mvdbent   65u  IPv4 0x64763030846e98dd      0t0  UDP *:53327
zoom.us   53231 mvdbent   67u  IPv4 0x6476303084763a55      0t0  UDP *:55248
zoom.us   53231 mvdbent   68u  IPv4 0x647630307bd37d3d      0t0  UDP *:53574
```

So i did a couple of test, ended the meeting, UDP connections where gone, started a new meeting, UDP connections are back turned. 
Turned off my Camera, then turned on, turned off the Microphone, and turned both off, the UDP connections where still there. **Awesome**
No we now where to look for when it comes to Zoom.us. 

We only need to list the network files with TCP state LISTEN, with the `-sTCP:LISTEN` option

Optional: We can specifies the IP version, IPv4 or IPv6 by adding `4` or `6`, in the script we specify IPv4.

**Example**
```bash
lsof -anP -i4 -sTCP:LISTEN | grep zoom
zoom.us   53231 mvdbent   60u  IPv4 0x64763030846e819d      0t0  UDP 10.0.1.116:63026
zoom.us   53231 mvdbent   61u  IPv4 0x64763030846e8d3d      0t0  UDP 10.0.1.116:58615
zoom.us   53231 mvdbent   65u  IPv4 0x64763030846e98dd      0t0  UDP *:53327
zoom.us   53231 mvdbent   67u  IPv4 0x6476303084763a55      0t0  UDP *:55248
zoom.us   53231 mvdbent   68u  IPv4 0x647630307bd37d3d      0t0  UDP *:53574

Usage:
		-a		causes list selection options to be ANDed, as described above.
		
		-n		inhibits the conversion of network numbers to host  names  for
				network  files.   Inhibiting  conversion  may  make  lsof  run
				faster.  It is also useful when host name lookup is not  working properly.
				
		-P		inhibits the conversion of port numbers to port names for network files.
				Inhibiting  the  conversion may make lsof run a little faster. 
				It is also useful when port name lookup is not working properly.

		-i 		selects  the  listing  of  files any of whose Internet address 
				matches the address specified in i.  If no address  is  specified, 
				this option selects the listing of all Internet and x.25
				(HP-UX) network files
				
		46 		specifies the IP version, IPv4 or IPv6 that applies to the following address.
				'6' may be be specified only if the UNIX dialect supports IPv6.
				If neither '4' nor '6' is specified, the following address applies to all IP versions.
				
		sTCP	To list only network files with TCP state LISTEN, use: -sTCP:LISTEN
```		

Fun fact is that beside of zoom.us, Microsoft Teams, Cisco WebEx, Slack and FaceTime is also using TCP state LISTEN.
Only Microsoft Teams connected this to your localIP

**Example**
```bash
lsof -anP -i4 -sTCP:LISTEN | grep Microsoft | grep 10.0.1.116:'*'
Microsoft 67439 mvdbent   45u  IPv4 0x647644287bdb076d      0t0  UDP 10.0.1.116:50023
```
This script will look for zoom.us, Microsoft Teams, Cisco WebEx, Slack and FaceTime online sessions.

**Want to Have**
Tried adding Discord, but it seems sort of not perfect.