#!/bin/bash

#############################################
# Simple PFC Enablement - ens192 only
# Direct approach for all 8 servers
#############################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SERVERS=(
    "192.168.11.152:ubunturdma1"
    "192.168.11.153:ubunturdma2"
    "192.168.11.154:ubunturdma3"
    "192.168.11.155:ubunturdma4"
    "192.168.11.107:ubunturdma5"
    "192.168.12.51:ubunturdma6"
    "192.168.20.150:ubunturdma7"
    "192.168.30.94:ubunturdma8"
)

run_ssh_sudo() {
    local ip=$1
    local cmd=$2

    /usr/bin/expect << EOFEXP
set timeout 60
spawn ssh -o StrictHostKeyChecking=no versa@${ip} "${cmd}"
expect {
    "password:" {
        send "<PASSWORD>\r"
        exp_continue
    }
    eof
}
EOFEXP
}

echo -e "${BLUE}========================================${NC}"
echo "Enable PFC on ens192 - All 8 Servers"
echo -e "${BLUE}========================================${NC}"
echo ""

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname <<< "$server_entry"

    echo ""
    echo -e "${BLUE}>>> $hostname ($ip)${NC}"
    echo ""

    echo -e "${CYAN}[1/6]${NC} Installing lldpad..."
    run_ssh_sudo "$ip" "echo '<PASSWORD>' | sudo -S apt-get update -qq && echo '<PASSWORD>' | sudo -S apt-get install -y lldpad" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[2/6]${NC} Starting lldpad service..."
    run_ssh_sudo "$ip" "echo '<PASSWORD>' | sudo -S systemctl start lldpad && echo '<PASSWORD>' | sudo -S systemctl enable lldpad" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[3/6]${NC} Enabling PFC TX on ens192..."
    run_ssh_sudo "$ip" "echo '<PASSWORD>' | sudo -S lldptool -T -i ens192 -V PFC enableTx=yes" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[4/6]${NC} Setting PFC priority 3 (RoCE)..."
    run_ssh_sudo "$ip" "echo '<PASSWORD>' | sudo -S lldptool -i ens192 -T -V PFC -c enabled=0,0,0,1,0,0,0,0" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[5/6]${NC} Configuring LLDP admin status..."
    run_ssh_sudo "$ip" "echo '<PASSWORD>' | sudo -S lldptool set-lldp -i ens192 adminStatus=rxtx" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[6/6]${NC} Verifying configuration..."
    run_ssh_sudo "$ip" "echo '<PASSWORD>' | sudo -S ethtool -a ens192" 2>&1 | grep -E "RX:|TX:"

    echo -e "${GREEN}✓ $hostname complete!${NC}"
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo "Commands executed on each server:"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "1. sudo apt-get update && sudo apt-get install -y lldpad"
echo "2. sudo systemctl start lldpad && sudo systemctl enable lldpad"
echo "3. sudo lldptool -T -i ens192 -V PFC enableTx=yes"
echo "4. sudo lldptool -i ens192 -T -V PFC -c enabled=0,0,0,1,0,0,0,0"
echo "5. sudo lldptool set-lldp -i ens192 adminStatus=rxtx"
echo "6. sudo ethtool -a ens192"
echo ""
echo -e "${GREEN}✓ PFC configuration complete!${NC}"
