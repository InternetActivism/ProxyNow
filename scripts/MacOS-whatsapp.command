#!/bin/bash

#################
#   Constants   #
#################

# Get directory where script was ran
dir="$(dirname "$0")"

# Get parent directory
parent_dir="$(dirname "$dir")"

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

# Change to the directory where the script was ran
cd "${dir}"

# Make log directory if it doesn't exist
mkdir -p "${log_dir}"

# Send stderr and stdout to the log file. Create 3 so we can still print to console manually
exec 3>&1 1>>"${log_file}" 2>&1

# Shared functions
pretty_print() {
  printf "\n%b\n" "$1" 1>&3
  printf "\n%b\n" "$1" >> "${log_file}"
}

pretty_print "Here we go..."

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

if ! command -v docker &>/dev/null; then
  pretty_print "Installing Docker..."
  brew install docker
else
  pretty_print "You already have Docker installed... good job!"
fi

if ! docker info >/dev/null 2>&1; then
  pretty_print "Opening Docker..."
  open -a Docker
fi

cd ../whatsapp-proxy/proxy

n=0
until [ "$n" -ge 5 ]
do
  if ! docker info >/dev/null 2>&1; then
    pretty_print "Docker does not seem to be running, retrying in 5 seconds"
  else
    break
  fi
  n=$((n+1)) 
  sleep 5
done

if [ "$n" -ge 5 ]; then
  pretty_print "Unable to start Docker, please try opening Docker manually and try again."
  exit 1
fi

pretty_print "Building the proxy host container.."
docker build . -t proxynow:1.0

if [ "$( docker container inspect -f '{{.State.Running}}' whatsapp-proxy )" == "true" ]; then
  pretty_print "WhatsApp proxy already running"
else
  if [ "$(docker ps -aq -f status=exited -f name=whatsapp-proxy)" ]; then
    docker rm /whatsapp-proxy
  fi 

  pretty_print "Running the proxy for WhatsApp.."
  docker run -d --name whatsapp-proxy -p 80:80 -p 443:443 -p 5222:5222 -p 8080:8080 -p 8443:8443 -p 8222:8222 -p 8199:8199 proxynow:1.0
fi 

if [ "$( docker container inspect -f '{{.State.Running}}' socks5 )" == "true" ]; then
  pretty_print "Telegram proxy already running"
else
  if [ "$(docker ps -aq -f status=exited -f name=socks5)" ]; then
    docker rm /socks5
  fi
  
  pretty_print "Running the proxy for Telegram.."
  docker run -d --name socks5 -p 1080:1080 serjs/go-socks5-proxy
fi 

# Get the local IP address
pretty_print "Getting proxy address.."
local_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}')
external_ip=$(curl ipecho.net/plain ; echo)

pretty_print "In WhatsApp, navigate to Settings > Storage and Data > Proxy"
pretty_print "Then, input your proxy address: $external_ip"
pretty_print "========================================"
pretty_print "In Telegram, navigate to Settings > Data and Storage > Proxy > Add Proxy"
pretty_print "Then, input your proxy address and your port: "
pretty_print "    Proxy Address: $external_ip"
pretty_print "    Port: 1080"

pretty_print "Mapping ports..."

brew install miniupnpc

# Use upnpc to map a port with the local IP
if upnpc -a $local_ip 443 443 TCP && upnpc -a $local_ip 1080 1080 TCP; then
    pretty_print "Ports 443 and 1080 have been successfully mapped to $local_ip"
else
    pretty_print "Unable to automatically map ports 443 and 1080. Please try manually port forwarding through your router's settings. For more information see the troubleshooting steps at the bottom of the setup page on ProxyNow."
fi

pretty_print "Your proxy is now running, thank you for setting one up. If you wish to share it publicly, please register $external_ip on ProxyNow."