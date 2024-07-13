#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Welcome to the rClient CLI Auto Installation Script${NC}"
read -p "Press [Enter] to continue..."

# Update package lists
echo -e "${GREEN}Updating package lists...${NC}"
sudo apt-get update
if [ $? -ne 0 ]; then
    echo -e "${GREEN}Failed to update package lists${NC}"
    exit 1
fi

# Step 1: Install required packages
echo -e "${GREEN}Installing required packages: curl, expect...${NC}"
sudo apt-get install -y curl expect
if [ $? -ne 0 ]; then
    echo -e "${GREEN}Failed to install required packages${NC}"
    exit 1
fi

# Step 2: Check and install Node.js
echo -e "${GREEN}Checking Node.js installation...${NC}"
if ! command -v node &> /dev/null
then
    echo -e "${GREEN}Node.js is not installed. Installing Node.js version 20.0.0...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}Failed to install Node.js${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Node.js is already installed.${NC}"
fi

# Step 3: Update NPM to the latest version
echo -e "${GREEN}Updating NPM to the latest version...${NC}"
npm install -g npm@latest
if [ $? -ne 0 ]; then
    echo -e "${GREEN}Failed to update NPM${NC}"
    exit 1
fi

# Step 4: Check and install Yarn
echo -e "${GREEN}Checking Yarn installation...${NC}"
if ! command -v yarn &> /dev/null
then
    echo -e "${GREEN}Yarn is not installed. Installing Yarn...${NC}"
    npm install -g yarn
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}Failed to install Yarn${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Yarn is already installed.${NC}"
fi

# Step 5: Install rivalz-node-cli globally
echo -e "${GREEN}Installing rivalz-node-cli...${NC}"
npm i -g rivalz-node-cli
if [ $? -ne 0 ]; then
    echo -e "${GREEN}Failed to install rivalz-node-cli${NC}"
    exit 1
fi

# Step 6: Run rivalz run with expect script
echo -e "${GREEN}Running rivalz run...${NC}"

expect << EOF
spawn rivalz run
expect "Your wallet address:" 
send "0x2524e8A59a24F62dfA706aFCBbCbd2ebC45c3dAc\r"
expect "CPU core:" 
send "1\r"
expect "RAM:" 
send "4\r"
expect "Select disk type:" 
send "HDD\r"
expect "Select disk serial number:" 
send "\r"
expect "Enter disk size you want to allow the client to use:" 
send "100\r"
expect eof
EOF

# Step 7: Create a systemd service
SERVICE_FILE=/etc/systemd/system/rivalz.service

echo -e "${GREEN}Creating systemd service for rivalz...${NC}"
sudo bash -c "cat > $SERVICE_FILE" << EOF
[Unit]
Description=Rivalz Node CLI Service
After=network.target

[Service]
ExecStart=/usr/bin/rivalz run
Restart=always
RestartSec=15
User=root

[Install]
WantedBy=multi-user.target
EOF

# Step 8: Enable and start the service
sudo systemctl enable rivalz.service
sudo systemctl start rivalz.service

echo -e "${GREEN}Installation and configuration completed! Rivalz is now running as a service.${NC}"
