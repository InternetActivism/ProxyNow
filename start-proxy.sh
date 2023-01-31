#!/bin/bash

#################
#   Constants   #
#################

# Log directory
log_dir="logs"

# The current time (used for log file name)
now=$(date +"%Y-%m-%d-%H-%M-%S")

# Get the log file path
log_file="${log_dir}/${now}.log"

######################
#   Setup Commands   #
######################

# exit when any command fails
set -e

# Make log directory if it doesn't exist
mkdir -p "${log_dir}"

# Send stderr and stdout to the log file. Create 3 so we can still print to console manually
exec 3>&1 1>>"${log_file}" 2>&1

# Get IPs
local_ip=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
external_ip=$(curl ipecho.net/plain ; echo)

# Unix time to share proxy with ProxyNow
currentUnixTime=$(date +%s)

# Shared functions
pretty_print() {
  printf "\n%b\n" "$1" 1>&3
  printf "\n%b\n" "$1" >> "${log_file}"
  # printf "\n%b\n" "$1"
}

share_prompt() {
 	while true; do
 		pretty_print "Would you like to share your proxies with ProxyNow to securely distribute it to those in need? (y/n)"
 		read share_yn

 		case $share_yn in
 			[Yy]* ) pretty_print "Sharing with ProxyNow..."
 				   curl -f  --location  --request POST 'https://proxynow-c699d-default-rtdb.firebaseio.com/proxynow-script/.json' \
 				   --header 'Content-Type: application/json' \
 				   -d '{
 	    				"ip": "'"$external_ip"'",
 	    				"port": "443",
 	    				"protocol": "https",
 	    				"platform": "whatsapp",
 	    				"createdTime": "'"$currentUnixTime"'"
 				   }' &&
           curl -f  --location  --request POST 'https://proxynow-c699d-default-rtdb.firebaseio.com/proxynow-script/.json' \
 				   --header 'Content-Type: application/json' \
 				   -d '{
 	    				"ip": "'"$external_ip"'",
 	    				"port": "1080",
 	    				"protocol": "https",
 	    				"platform": "telegram",
 	    				"createdTime": "'"$currentUnixTime"'"
 				   }' &&
 				   pretty_print "Shared with ProxyNow." ||
 				   pretty_print "Something went wrong. Could not share with ProxyNow."
 				   break;;
 			[Nn]* ) pretty_print "Not sharing with ProxyNow..."
 				   break;;
 	    		    * ) pretty_print "Please respond with y or n";;
 		esac
 	done

 }


#######################
#   Script Commands   #
#######################

pretty_print "Hey! Welcome to ProxyNow! This script will automatically take you through setting up a Proxy to help people in Iran access the internet.

Before we begin, this script will install some software that handles proxy infrastructure such as homebrew and docker. All of this software is secure and vetted by industry professionals. 

You will also be asked if you want to share your proxy with ProxyNow. We recommend that you accept by entering "y" and pressing return when prompted so that we can securely distribute your proxy to those in need.

You must keep this terminal on for your proxy to keep running, but you can stop this process at any time by pressing CTRL+C.
"

pretty_print "Updating apt, git and curl if necesary..."

sudo apt update
sudo apt-get -y install git-all
sudo apt -y install curl

if [ -x "$(command -v docker)" ]; then
   pretty_print "Checking for Docker updates..."
else
   pretty_print "Installing Docker..."

   # Setup Docker repository
   sudo apt-get -y install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
   sudo mkdir -p /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

# Install Docker / check for updates
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

pretty_print "Installing Docker Compose... "
# Download the pkg
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/bin/docker-compose
# Enable execution of the script
sudo chmod +x /usr/bin/docker-compose

pretty_print "Building and running Docker container... "
service docker start

PORTS="80 443 5222 8080 8443 8222 8199 1080"
for p in $PORTS
do
   output=$(lsof -i :$p | grep -v "COMMAND" | awk '{ print $1 }')
   if [[ -n "$output" ]] ; then
      pretty_print "ERROR: Process running on port $p"
      while true; do
         pretty_print "Would you like to close the process? (y/n)"
         read yn
         case $yn in
            [Yy]* ) kill $(lsof -t -i:$p); break;;
            [Nn]* ) exit;;
                * ) pretty_print "Please respond with y or n";;
         esac
      done
   fi
done

pretty_print "Mapping ports..."

apt-get -y install miniupnpc

# Use upnpc to map a port with the local IP
if upnpc -a $local_ip 443 443 TCP; then
    pretty_print "Port 443 has been successfully mapped to $local_ip"
else
    pretty_print "WARNING: Unable to automatically map port 443. Please try manually port forwarding to $local_ip through your router's settings. For more information see the troubleshooting steps at the bottom of the setup page on ProxyNow."
fi

# Setup proxy for WhatsApp
if [ "$( docker container inspect -f '{{.State.Running}}' whatsapp-proxy )" == "true" ]; then
  pretty_print "WhatsApp proxy already running"
else
  if [ "$(docker ps -aq -f status=exited -f name=whatsapp-proxy)" ]; then
    docker rm /whatsapp-proxy
  fi 
  pretty_print "Running the proxy for WhatsApp.."
  docker pull facebook/whatsapp_proxy:latest
  docker run -d --name whatsapp-proxy -p 80:80 -p 443:443 -p 5222:5222 -p 8080:8080 -p 8443:8443 -p 8222:8222 -p 8199:8199 facebook/whatsapp_proxy:latest
fi 
pretty_print "In WhatsApp, navigate to Settings > Storage and Data > Proxy"
pretty_print "Then, input your proxy address: $external_ip"

# Setup proxy for Telegram
if [ "$( docker container inspect -f '{{.State.Running}}' socks5 )" == "true" ]; then
  pretty_print "Telegram proxy already running"
else
  if [ "$(docker ps -aq -f status=exited -f name=socks5)" ]; then
    docker rm /socks5
  fi
  pretty_print "Running the proxy for Telegram.."
  docker run -d --name socks5 -p 1080:1080 serjs/go-socks5-proxy
fi
pretty_print "In Telegram, navigate to Settings > Data and Storage > Proxy > Add Proxy"
pretty_print "Then, input your proxy address and your port: "
pretty_print "    Proxy Address: $external_ip"
pretty_print "    Port: 1080"

share_prompt

pretty_print "Hit Control+C to stop the proxies"

( trap exit SIGINT ; read -r -d '' _ </dev/tty ) ## wait for Ctrl-C

pretty_print "Shutting down proxy... "

docker stop /whatsapp-proxy
docker stop /socks5
