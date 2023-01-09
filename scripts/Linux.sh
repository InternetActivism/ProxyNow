#The convenience script to install ubuntu easily: 
#https://docs.docker.com/engine/install/ubuntu/

#install docker on ubuntu
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

#Follow the readme of https://github.com/WhatsApp/proxy/

# Download the pkg
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/bin/docker-compose
# Enable execution of the script
sudo chmod +x /usr/bin/docker-compose

git clone https://github.com/WhatsApp/proxy.git
sudo Docker build proxy/proxy -t whatsapp_proxy:1.0
sudo docker run -it -p 80:80 -p 443:443 -p 5222:5222 -p 8080:8080 -p 8443:8443 -p 8222:8222 -p 8199:8199 whatsapp_proxy:1.0

#If you want to use docker compose, follow the readme at https://github.com/WhatsApp/proxy/