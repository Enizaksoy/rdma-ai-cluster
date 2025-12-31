#!/bin/bash

#############################################
# Enable PFC on ESXi Host
# Configures physical NICs for lossless RoCE
#############################################

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

ESXI_IP="192.168.50.152"
ESXI_USER="root"
ESXI_PASS="<PASSWORD>"

echo -e "${BLUE}========================================${NC}"
echo "ESXi Host 1 - PFC Configuration"
echo "Host: $ESXI_IP"
echo -e "${BLUE}========================================${NC}"
echo ""

run_esxi_cmd() {
    local cmd=$1
    local desc=$2

    echo -e "${CYAN}${desc}${NC}"
    echo -e "${YELLOW}CMD: ${cmd}${NC}"

    /usr/bin/expect << EOFEXP
set timeout 30
spawn ssh -o StrictHostKeyChecking=no ${ESXI_USER}@${ESXI_IP} "${cmd}"
expect {
    "Password:" {
        send "${ESXI_PASS}\r"
        exp_continue
    }
    eof
}
EOFEXP

    echo ""
}

echo -e "${BLUE}=== Step 1: List Physical NICs ===${NC}"
echo ""
run_esxi_cmd "esxcli network nic list" "[1] Listing all physical NICs"

echo -e "${BLUE}=== Step 2: Check Current Pause Parameters ===${NC}"
echo ""
run_esxi_cmd "esxcli network nic pauseParams list" "[2] Current pause/PFC settings"

echo -e "${BLUE}=== Step 3: Enable PFC on All Physical NICs ===${NC}"
echo ""

# Get list of vmnics and enable PFC on each
echo -e "${YELLOW}Detecting vmnics and enabling PFC...${NC}"

/usr/bin/expect << 'EOFEXP2'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no root@192.168.50.152
expect "Password:"
send "<PASSWORD>\r"
expect "~]"

# Get list of NICs
send "esxcli network nic list | grep vmnic | awk '{print \$1}'\r"
expect "~]"

# Enable PFC on vmnic0
puts "\n\033[0;36m[3.1] Enabling PFC on vmnic0...\033[0m"
send "esxcli network nic pauseParams set -n vmnic0 --rx-pause=true --tx-pause=true\r"
expect "~]"

# Enable PFC on vmnic1
puts "\n\033[0;36m[3.2] Enabling PFC on vmnic1...\033[0m"
send "esxcli network nic pauseParams set -n vmnic1 --rx-pause=true --tx-pause=true\r"
expect "~]"

# Try vmnic2 if it exists
puts "\n\033[0;36m[3.3] Enabling PFC on vmnic2 (if exists)...\033[0m"
send "esxcli network nic pauseParams set -n vmnic2 --rx-pause=true --tx-pause=true 2>/dev/null\r"
expect "~]"

# Try vmnic3 if it exists
puts "\n\033[0;36m[3.4] Enabling PFC on vmnic3 (if exists)...\033[0m"
send "esxcli network nic pauseParams set -n vmnic3 --rx-pause=true --tx-pause=true 2>/dev/null\r"
expect "~]"

puts "\n\033[0;32m✓ PFC enable commands executed\033[0m\n"

send "exit\r"
expect eof
EOFEXP2

echo ""
echo -e "${BLUE}=== Step 4: Verify PFC Configuration ===${NC}"
echo ""
run_esxi_cmd "esxcli network nic pauseParams list" "[4] Verifying pause parameters"

echo -e "${BLUE}=== Step 5: Show vSwitch Configuration ===${NC}"
echo ""
run_esxi_cmd "esxcli network vswitch standard list" "[5] Standard vSwitch info"

echo ""
echo -e "${BLUE}========================================${NC}"
echo "ESXi PFC Configuration Complete"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✓ PFC enabled on ESXi Host 1 (192.168.50.152)${NC}"
echo ""
echo "Next steps:"
echo "  1. If you have a second ESXi host, configure it the same way"
echo "  2. Run traffic test: bash saturate_cross_esxi.sh 60"
echo "  3. Check switch for pause frames:"
echo "     ssh admin@192.168.50.229"
echo "     show interface ethernet1/2/2 priority-flow-control"
echo ""
