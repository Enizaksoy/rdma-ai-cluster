#!/bin/bash

#############################################
# Detect RDMA Interfaces (VLAN 250/251)
# Find which interface has 192.168.250.x or 192.168.251.x
#############################################

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

echo -e "${BLUE}========================================${NC}"
echo "Detecting RDMA Interfaces (VLAN 250/251)"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Looking for interfaces with 192.168.250.x or 192.168.251.x"
echo ""

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname <<< "$server_entry"

    echo -e "${CYAN}$hostname ($ip):${NC}"

    /usr/bin/expect << EOFEXP 2>&1 | grep -E "ens[0-9]+|192.168.(250|251)" | head -10
set timeout 10
spawn ssh -o StrictHostKeyChecking=no versa@${ip} "ip addr show | grep -E 'ens[0-9]+|192.168.(250|251)'"
expect {
    "password:" {
        send "<PASSWORD>\r"
        exp_continue
    }
    eof
}
EOFEXP

    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo "Summary"
echo -e "${BLUE}========================================${NC}"
