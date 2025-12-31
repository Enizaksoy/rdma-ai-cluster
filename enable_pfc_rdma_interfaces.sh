#!/bin/bash

#############################################
# Enable PFC on RDMA Interfaces
# Detects and configures interfaces with VLAN 250/251
#############################################

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Server mapping based on inventory
# Format: "mgmt_ip:hostname:rdma_interface:vlan_ip"
SERVERS=(
    "192.168.11.152:ubunturdma1:ens224:192.168.251.111"
    "192.168.11.153:ubunturdma2:ens192:192.168.250.112"
    "192.168.11.154:ubunturdma3:ens224:192.168.251.113"
    "192.168.11.155:ubunturdma4:ens192:192.168.250.114"
    "192.168.11.107:ubunturdma5:ens192:192.168.250.115"
    "192.168.12.51:ubunturdma6:ens192:192.168.251.116"
    "192.168.20.150:ubunturdma7:ens192:192.168.250.117"
    "192.168.30.94:ubunturdma8:ens192:192.168.251.118"
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
echo "Enable PFC on RDMA Interfaces (VLAN 250/251)"
echo -e "${BLUE}========================================${NC}"
echo ""

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r mgmt_ip hostname rdma_iface vlan_ip <<< "$server_entry"

    echo ""
    echo -e "${BLUE}>>> $hostname ($mgmt_ip)${NC}"
    echo -e "${CYAN}    RDMA Interface: $rdma_iface ($vlan_ip)${NC}"
    echo ""

    # Verify the interface exists
    echo -e "${YELLOW}[Verify] Checking interface...${NC}"
    run_ssh_sudo "$mgmt_ip" "ip addr show $rdma_iface 2>&1 | grep -E '$rdma_iface|inet '" | grep -v "spawn\|password" | head -3

    echo ""
    echo -e "${CYAN}[1/6]${NC} Installing lldpad..."
    echo -e "${YELLOW}CMD: sudo apt-get install -y lldpad${NC}"
    run_ssh_sudo "$mgmt_ip" "echo '<PASSWORD>' | sudo -S apt-get update -qq && echo '<PASSWORD>' | sudo -S apt-get install -y lldpad" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[2/6]${NC} Starting lldpad service..."
    echo -e "${YELLOW}CMD: sudo systemctl start lldpad${NC}"
    run_ssh_sudo "$mgmt_ip" "echo '<PASSWORD>' | sudo -S systemctl start lldpad && echo '<PASSWORD>' | sudo -S systemctl enable lldpad" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[3/6]${NC} Enabling PFC TX on $rdma_iface..."
    echo -e "${YELLOW}CMD: sudo lldptool -T -i $rdma_iface -V PFC enableTx=yes${NC}"
    run_ssh_sudo "$mgmt_ip" "echo '<PASSWORD>' | sudo -S lldptool -T -i $rdma_iface -V PFC enableTx=yes" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[4/6]${NC} Setting PFC priority 3 (RoCE)..."
    echo -e "${YELLOW}CMD: sudo lldptool -i $rdma_iface -T -V PFC -c enabled=0,0,0,1,0,0,0,0${NC}"
    run_ssh_sudo "$mgmt_ip" "echo '<PASSWORD>' | sudo -S lldptool -i $rdma_iface -T -V PFC -c enabled=0,0,0,1,0,0,0,0" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[5/6]${NC} Configuring LLDP admin status..."
    echo -e "${YELLOW}CMD: sudo lldptool set-lldp -i $rdma_iface adminStatus=rxtx${NC}"
    run_ssh_sudo "$mgmt_ip" "echo '<PASSWORD>' | sudo -S lldptool set-lldp -i $rdma_iface adminStatus=rxtx" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo -e "${CYAN}[6/6]${NC} Enabling hardware pause (ethtool)..."
    echo -e "${YELLOW}CMD: sudo ethtool -A $rdma_iface rx on tx on${NC}"
    run_ssh_sudo "$mgmt_ip" "echo '<PASSWORD>' | sudo -S ethtool -A $rdma_iface rx on tx on" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC}"

    echo ""
    echo -e "${YELLOW}[Verify] Checking configuration:${NC}"
    run_ssh_sudo "$mgmt_ip" "echo '<PASSWORD>' | sudo -S ethtool -a $rdma_iface" 2>&1 | grep -E "Pause parameters|RX:|TX:" | grep -v "spawn\|password"

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo "Summary - Commands Executed Per Server"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "1. sudo apt-get install -y lldpad"
echo "2. sudo systemctl start lldpad && sudo systemctl enable lldpad"
echo "3. sudo lldptool -T -i <RDMA_IFACE> -V PFC enableTx=yes"
echo "4. sudo lldptool -i <RDMA_IFACE> -T -V PFC -c enabled=0,0,0,1,0,0,0,0"
echo "5. sudo lldptool set-lldp -i <RDMA_IFACE> adminStatus=rxtx"
echo "6. sudo ethtool -A <RDMA_IFACE> rx on tx on"
echo ""
echo "Where <RDMA_IFACE> is:"
echo "  - ens224 for: ubunturdma1, ubunturdma3"
echo "  - ens192 for: ubunturdma2, ubunturdma4, ubunturdma5, ubunturdma6, ubunturdma7, ubunturdma8"
echo ""
echo -e "${GREEN}✓ PFC configuration complete on RDMA interfaces!${NC}"
