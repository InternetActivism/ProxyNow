#!/bin/bash

# Shared functions
pretty_print() {
  printf "\n%b\n" "$1"
}
# 
pretty_print "Here we go..."

# So it begins


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
  pretty_print "You already have Docker installed...good job!"
fi

open -a Docker

cd ../whatsapp-proxy/proxy

n=0
until [ "$n" -ge 5 ]
do
  if ! docker info >/dev/null 2>&1; then
    pretty_print "Docker does not seem to be running, retrying in 5 seconds"
  fi
  n=$((n+1)) 
  sleep 5
done

pretty_print "Building the proxy host container.."
docker build . -t proxynow:1.0

docker stop /whatsapp-proxy
docker stop /socks5
docker rm /whatsapp-proxy
docker rm /socks5

pretty_print "Running the proxy for WhatsApp.."
docker run -d --name whatsapp-proxy -p 80:80 -p 443:443 -p 5222:5222 -p 8080:8080 -p 8443:8443 -p 8222:8222 -p 8199:8199 proxynow:1.0

pretty_print "Running the proxy for Telegram.."
docker run -d --name socks5 -p 1080:1080 serjs/go-socks5-proxy

# Get the local IP address
pretty_print "Getting proxy address.."
local_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}')

pretty_print "In WhatsApp, navigate to Settings > Storage and Data > Proxy"
pretty_print "Then, input your proxy address: "
pretty_print $local_ip
pretty_print "========================================"
pretty_print "In Telegram, navigate to Settings > Data and Storage > Proxy > Add Proxy"
pretty_print "Then, input your proxy address and your port: "
pretty_print $local_ip
pretty_print "1080"

#brew install miniupnpc
#upnpc -a $local_ip 443 443 TCP # Use upnpc to map a port with the local IP

#echo "Port 443 has been successfully mapped to $local_ip using upnpc."