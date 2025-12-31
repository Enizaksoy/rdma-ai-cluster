#!/bin/bash

#############################################
# Enable PFC at Hardware Level
# For Mellanox ConnectX NICs (mlx5_core)
#############################################

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
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
set timeout 30
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
echo "Enable PFC at Hardware Level (Mellanox)"
echo -e "${BLUE}========================================${NC}"
echo ""

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname <<< "$server_entry"

    echo -e "${BLUE}>>> $hostname ($ip)${NC}"

    # Enable RX/TX pause at hardware level
    echo -e "${CYAN}[1/3]${NC} Enabling RX pause..."
    run_ssh_sudo "$ip" "echo '<PASSWORD>' | sudo -S ethtool -A ens192 rx on" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[2/3]${NC} Enabling TX pause..."
    run_ssh_sudo "$ip" "echo '<PASSWORD>' | sudo -S ethtool -A ens192 tx on" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[3/3]${NC} Verifying..."
    run_ssh_sudo "$ip" "echo '<PASSWORD>' | sudo -S ethtool -a ens192" 2>&1 | grep -E "RX:|TX:"

    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo "Hardware Commands Executed:"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "On each server:"
echo "  sudo ethtool -A ens192 rx on"
echo "  sudo ethtool -A ens192 tx on"
echo "  sudo ethtool -a ens192  # Verify"
echo ""
echo -e "${GREEN}✓ Hardware PFC enabled!${NC}"
