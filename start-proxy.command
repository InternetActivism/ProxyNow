#!/bin/bash

#################
#   Constants   #
#################

# Get directory where script was ran
dir="$(dirname "$0")"

# Get parent directory
parent_dir="$(dirname "$dir")"

# Log directory
log_dir="${dir}/logs"

# The current time (used for log file name)
now=$(date +"%Y-%m-%d-%H-%M-%S")

# Get the log file path
log_file="${log_dir}/${now}.log"

######################
#   Setup Commands   #
######################

# exit when any command fails
set -e

# Change to the directory where the script was ran
cd "${dir}"

# Make log directory if it doesn't exist
mkdir -p "${log_dir}"

# Send stderr and stdout to the log file. Create 3 so we can still print to console manually
exec 3>&1 1>>"${log_file}" 2>&1

# Get IPs
local_ip=$(ifconfig | awk '/inet /&&!/127.0.0.1/{print $2;exit}')
external_ip=$(curl ipecho.net/plain ; echo)
router_ip=$(netstat -nr | grep default | grep -v tun | awk '{print $2}')

# Stop colima if running
colima stop

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

pretty_print "Hey! Welcome to ProxyNow! This script will automatically take you through setting up a Proxy to help people in Iran access the internet.

Before we begin, this script will install some software that handles proxy infrastructure such as homebrew and docker. All of this software is secure and vetted by industry professionals. 

You will also be asked if you want to share your proxy with ProxyNow. We recommend that you accept by entering "y" and pressing return when prompted so that we can securely distribute your proxy to those in need.

You must keep this terminal on for your proxy to keep running, but you can stop this process at any time by pressing CTRL+C.
"

# Homebrew installation

if ! command -v brew &>/dev/null; then
  pretty_print "Installing Homebrew, an OSX package manager, follow the instructions..." 
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

  if ! grep -qs "recommended by brew doctor" ~/.zshrc; then
    pretty_print "Put Homebrew location earlier in PATH ..."
      printf '\n# recommended by brew doctor\n' >> ~/.zshrc
      printf 'export PATH="/usr/local/bin:$PATH"\n' >> ~/.zshrc
      export PATH="/usr/local/bin:$PATH"
  fi
else
  pretty_print "You already have Homebrew installed...good job!"
fi

# Homebrew OSX libraries

pretty_print "Updating brew formulas"
  	brew update

pretty_print "Installing GNU core utilities..."
	brew install coreutils

pretty_print "Installing GNU find, locate, updatedb and xargs..."
	brew install findutils

printf 'export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"' >> ~/.zshrc
export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"

pretty_print "Installing Docker... (this may take a few minutes)"
	brew install docker
	brew install docker-compose
	brew install colima
	colima start

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
pretty_print "In WhatsApp, navigate to Settings > Storage and Data > Proxy
Then, input your proxy address: $external_ip"


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
pretty_print "In Telegram, navigate to Settings > Data and Storage > Proxy > Add Proxy
Select SOCKS5 then input your proxy address and your port: 
    Proxy Address: $external_ip
    Port: 1080"

pretty_print "Mapping ports..."

brew install miniupnpc

# Use upnpc to map a port with the local IP
if upnpc -a $local_ip 443 443 TCP && upnpc -a $local_ip 1080 1080 TCP; then
    pretty_print "Ports 443 and 1080 have been successfully mapped to $local_ip"
else
    pretty_print "Unable to automatically map ports 443 and 1080 which means your proxy may not work. Double check that you are not on a public network and please try manually port forwarding by going to $router_ip and selecting the device with the IP address $local_ip then forward ports 443 and 1080. For more information see the troubleshooting steps at the bottom of the setup page on ProxyNow."
fi

share_prompt

pretty_print "Hit Control+C to stop the proxies"

( trap exit SIGINT ; read -r -d '' _ </dev/tty ) ## wait for Ctrl-C

pretty_print "Shutting down proxies... "

docker stop /whatsapp-proxy
docker stop /socks5
colima stop
