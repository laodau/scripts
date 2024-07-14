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
sudo systemctl daemon-reload
sudo systemctl enable rivalz.service
sudo systemctl start rivalz.service

echo -e "${GREEN}Installation and configuration completed! Rivalz is now running as a service.${NC}"

echo "--------------------------- Configuration INFO ---------------------------"
echo "CPU: " $(nproc --all) "vCPU"
echo -n "RAM: " && free -h | awk '/Mem/ {sub(/Gi/, " GB", $2); print $2}'
echo "Disk Space" $(df -B 1G --total | awk '/total/ {print $2}' | tail -n 1) "GB"
echo "--------------------------------------------------------------------------"


echo "--------------------------- BASH SHELL TITAN ---------------------------"
# Fixed hash
hash_value="60CA5D2F-585D-458F-BF73-C297B63BDE9A"

cpu_core=1
memory_size=4
storage_size=80

service_content="
[Unit]
Description=Titan Node
After=network.target
StartLimitIntervalSec=0

[Service]
User=root
ExecStart=/usr/local/titan/titan-edge daemon start
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
"

sudo apt-get update
sudo apt-get install -y nano

VERSION='v0.1.19'
PATCH="89e53b6"

wget https://github.com/Titannet-dao/titan-node/releases/download/${VERSION}/titan-l2edge_${VERSION}_patch_linux_amd64.tar.gz

sudo tar -xf titan-l2edge_${VERSION}_patch_linux_amd64.tar.gz -C /usr/local

sudo mv /usr/local/titan-edge_${VERSION}_${PATCH}_linux_amd64 /usr/local/titan
sudo cp /usr/local/titan/libgoworkerd.so /usr/lib/libgoworkerd.so

rm titan-l2edge_${VERSION}_patch_linux_amd64.tar.gz

# Định nghĩa nội dung cần thêm
content="
export PATH=\$PATH:/usr/local/titan
export LD_LIBRARY_PATH=\$LD_LIZBRARY_PATH:./libgoworkerd.so
"

# Kiểm tra nếu file ~/.bash_profile chưa tồn tại thì tạo mới, nếu đã tồn tại thì ghi thêm
if [ ! -f ~/.bash_profile ]; then
  echo "$content" > ~/.bash_profile
  source ~/.bash_profile
else
  echo "$content" >> ~/.bash_profile
  source ~/.bash_profile
fi

echo "Export PATH ~/.bash_profile"


# Chạy titan-edge daemon trong nền
(titan-edge daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0 &) &
daemon_pid=$!

echo "PID of titan-edge daemon: $daemon_pid"

# Chờ 10 giây để đảm bảo rằng daemon đã khởi động thành công
sleep 30

# Chạy titan-edge bind trong nền
(titan-edge bind --hash="$hash_value" https://api-test1.container1.titannet.io/api/v2/device/binding &) &
bind_pid=$!

echo "PID of titan-edge bind: $bind_pid"

# Chờ cho quá trình bind kết thúc
wait $bind_pid

sleep 20

# Tiến hành các cài đặt khác

config_file="/root/.titanedge/config.toml"
if [ -f "$config_file" ]; then
    sed -i "s/#StorageGB = 2/StorageGB = $storage_size/" "$config_file"
    echo "Config StorageGB to: $storage_size GB."
    sed -i "s/#MemoryGB = 1/MemoryGB = $memory_size/" "$config_file"
    echo "Config MemoryGB to: $memory_size GB."
    sed -i "s/#Cores = 1/Cores = $cpu_core/" "$config_file"
    echo "Config Cores CPU to: $cpu_core Core."
else
    echo "Error: Configuration file $config_file does not exist."
fi

echo "$service_content" | sudo tee /etc/systemd/system/titand.service > /dev/null

# Dừng các tiến trình liên quan đến titan-edge
pkill titan-edge

# Cập nhật systemd
sudo systemctl daemon-reload

# Kích hoạt và khởi động titand.service
sudo systemctl enable titand.service
sudo systemctl start titand.service

sleep 8
# Hiển thị thông tin và cấu hình của titan-edge
sudo systemctl status titand.service && titan-edge config show && titan-edge info
