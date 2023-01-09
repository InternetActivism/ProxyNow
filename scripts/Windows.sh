### Run Command Prompt as Admin ###

# Only necessary if WSL isn't already installed, can check with `wsl --status`
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
## Restart ##

# Start here is WSL is already installed
wsl --install -d Ubuntu
## Restart ##

# After restart, Ubuntu will open automatically and initialize, takes few minutes
# If Ubuntu doesn't automatically open, run `wsl -d Ubuntu` from Command Prompt

# Installing docker (https://docs.docker.com/engine/install/ubuntu/)
# Uninstall old versions (not necessary but doesn't hurt)
sudo apt-get remove docker docker-engine docker.io containerd runc

# Setup Docker repository
sudo apt-get update
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

# Install Docker Engine
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Run Docker Engine
sudo service docker start

# Clone the repository and navigate to the proxy folder
git clone https://github.com/whatsapp/proxy.git
cd proxy/proxy

# Build the proxy host container
sudo docker build . -t whatsapp_proxy:1.0

# Run the proxy
sudo docker run -it -p 80:80 -p 443:443 -p 5222:5222 -p 8080:8080 -p 8443:8443 -p 8222:8222 -p 8199:8199 whatsapp_proxy:1.0