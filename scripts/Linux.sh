#!/bin/bash

#################
#   Constants   #
#################

# Get the parent directory
parent_dir="$(cd ../ && pwd)"

# Log directory
log_dir="${parent_dir}/logs"

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

# Shared functions
pretty_print() {
  printf "\n%b\n" "$1" 1>&3
  printf "\n%b\n" "$1" >> "${log_file}"
  # printf "\n%b\n" "$1"
}

#######################
#   Script Commands   #
#######################

pretty_print "Here we go..."

if [ "$( docker container inspect -f '{{.State.Running}}' whatsapp_proxy )" == "true" ]; then
   pretty_print "WhatsApp proxy already running, shutting down old instance"
   docker-compose -f ${parent_dir}/whatsapp-proxy/proxy/ops/docker-compose.yml stop
fi

pretty_print "Updating apt and git if necesary..."

sudo apt update
sudo apt-get install git-all

if [ -x "$(command -v docker)" ]; then
   pretty_print "Checking for Docker updates..."
else
   pretty_print "Installing Docker..."

   # Setup Docker repository
   sudo apt-get install \
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
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

pretty_print "Installing Docker Compose... "
# Download the pkg
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/bin/docker-compose
# Enable execution of the script
sudo chmod +x /usr/bin/docker-compose

pretty_print "Building and running Docker container... "
service docker start

output=$(lsof -i :80 -i :443 -i :5222 -i :8080 -i :8443 -i :8222 -i :8199 | grep -v "COMMAND" | awk '{ print $1 }')
if [[ -n "$output" ]] ; then
   pretty_print "ERROR: Some ports required for proxy are in use, please end processes running on ports 80, 443, 5222, 8080, 8443, 8222 or 8199 and try again"
   exit 1
fi

pretty_print "Mapping ports..."

apt-get install miniupnpc

local_ip=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
external_ip=$(curl ipecho.net/plain ; echo)

# Use upnpc to map a port with the local IP
if upnpc -a $local_ip 443 443 TCP; then
    pretty_print "Port 443 has been successfully mapped to $local_ip"
else
    pretty_print "WARNING: Unable to automatically map port 443. Please try manually port forwarding to $local_ip through your router's settings. For more information see the troubleshooting steps at the bottom of the setup page on ProxyNow."
fi

docker-compose -f ../whatsapp-proxy/proxy/ops/docker-compose.yml up -d

pretty_print "In WhatsApp, navigate to Settings > Storage and Data > Proxy"
pretty_print "Then, input your proxy address: $external_ip"

pretty_print "Your proxy is now running, thank you for setting one up. If you wish to share it publicly, please register $external_ip on ProxyNow."

pretty_print "Hit Control+C to stop the proxy"

( trap exit SIGINT ; read -r -d '' _ </dev/tty ) ## wait for Ctrl-C

pretty_print "Shutting down proxy... "

docker-compose -f ${parent_dir}/whatsapp-proxy/proxy/ops/docker-compose.yml stop
