#!/bin/bash

#################
#   Constants   #
#################

# Log directory
log_dir="_data/logs"

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
		pretty_print "Would you like to share your proxy with ProxyNow to securely distribute it to those in need? (y/n)"
		read share_yn

		case $share_yn in
			[Yy]* ) pretty_print "Sharing with ProxyNow..."
				curl -f  --location  --request POST 'https://proxynow-c699d-default-rtdb.firebaseio.com/proxynow-script/.json' \
				--header 'Content-Type: application/json' \
				-d '{
	    				"ip": "'"$external_ip"'",
	    				"port": "'"$1"'",
	    				"protocol": "https",
	    				"platform": "'"$2"'",
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

pretty_print "Here we go..."

if [ "$( docker container inspect -f '{{.State.Running}}' whatsapp_proxy )" == "true" ]; then
   pretty_print "WhatsApp proxy already running, shutting down old instance"
   docker-compose -f _data/proxy/ops/docker-compose.yml stop
fi

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

while true; do
    pretty_print "Would you like to start the WhatsApp proxy? (y/n)"
    read whatsapp_yn
    case $whatsapp_yn in
        [Yy]* )
                docker-compose -f _data/proxy/ops/docker-compose.yml up -d
                pretty_print "WhatsApp proxy is now running!"
                pretty_print "In WhatsApp, navigate to Settings > Storage and Data > Proxy"
                pretty_print "Then, input your proxy address: $external_ip"
		share_prompt "443" "whatsapp"
                break;;
        [Nn]* ) break;;
            * ) pretty_print "Please respond with y or n";;
    esac
done

while true; do
    pretty_print "Would you like to start the Telegram proxy? (y/n)"
    read telegram_yn
    case $telegram_yn in
        [Yy]* )
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
		share_prompt "1080" "telegram"
                break;;
        [Nn]* ) break;;
            * ) echo "Please respond with y or n";;
    esac
done

pretty_print "Hit Control+C to stop the proxies"

( trap exit SIGINT ; read -r -d '' _ </dev/tty ) ## wait for Ctrl-C

pretty_print "Shutting down proxy... "

docker-compose -f _data/proxy/ops/docker-compose.yml stop
docker stop /socks5
