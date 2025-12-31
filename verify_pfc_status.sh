#!/bin/bash

#############################################
# Comprehensive PFC Verification
# Shows all ways to check PFC status
#############################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SERVER_IP=${1:-"192.168.11.152"}
SERVER_NAME=${2:-"ubunturdma1"}

echo -e "${BLUE}========================================${NC}"
echo "PFC Verification Commands for $SERVER_NAME"
echo -e "${BLUE}========================================${NC}"
echo ""

run_ssh() {
    local cmd=$1
    local desc=$2

    echo -e "${CYAN}${desc}:${NC}"
    echo -e "${YELLOW}$ ${cmd}${NC}"

    /usr/bin/expect << EOFEXP > /tmp/pfc_check_$$.txt 2>&1
set timeout 10
spawn ssh -o StrictHostKeyChecking=no versa@${SERVER_IP} "${cmd}"
expect {
    "password:" {
        send "<PASSWORD>\r"
        exp_continue
    }
    eof
}
EOFEXP

    cat /tmp/pfc_check_$$.txt | grep -v "spawn\|password\|versa@"
    echo ""
    rm -f /tmp/pfc_check_$$.txt
}

echo -e "${BLUE}=== Method 1: Check ethtool pause parameters ===${NC}"
echo ""
run_ssh "sudo ethtool -a ens192" "sudo ethtool -a ens192"

echo -e "${BLUE}=== Method 2: Check LLDP/DCB PFC configuration ===${NC}"
echo ""
run_ssh "sudo lldptool -t -i ens192 -V PFC 2>/dev/null || echo 'lldptool not configured'" "sudo lldptool -t -i ens192 -V PFC"

echo -e "${BLUE}=== Method 3: Check network interface statistics ===${NC}"
echo ""
run_ssh "sudo ethtool -S ens192 | grep -i 'pfc\\|pause' | head -20" "sudo ethtool -S ens192 | grep pfc/pause"

echo -e "${BLUE}=== Method 4: Check RDMA device capabilities ===${NC}"
echo ""
run_ssh "ibv_devinfo -d rocep11s0 2>/dev/null | grep -A 5 'port:' || ibv_devinfo -d rocep19s0 2>/dev/null | grep -A 5 'port:'" "ibv_devinfo (RDMA device info)"

echo -e "${BLUE}=== Method 5: Check sysfs for PFC/ECN ===${NC}"
echo ""
run_ssh "find /sys/class/net/ens192 -name '*pfc*' -o -name '*ecn*' 2>/dev/null | xargs ls -la 2>/dev/null || echo 'No PFC sysfs entries found'" "Check sysfs for PFC files"

echo -e "${BLUE}=== Method 6: Check traffic class configuration ===${NC}"
echo ""
run_ssh "tc qdisc show dev ens192" "tc qdisc show dev ens192"

echo ""
echo -e "${BLUE}========================================${NC}"
echo "Summary: How to Verify PFC is Working"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "1. ON THE SERVER - Run these commands:"
echo "   ${CYAN}sudo ethtool -a ens192${NC}"
echo "   ${CYAN}sudo lldptool -t -i ens192 -V PFC${NC}"
echo "   ${CYAN}sudo ethtool -S ens192 | grep pfc${NC}"
echo ""
echo "2. ON THE SWITCH - Check for pause frames during traffic:"
echo "   ${CYAN}ssh admin@192.168.50.229${NC}"
echo "   ${CYAN}show interface ethernet1/2/2 priority-flow-control${NC}"
echo "   ${CYAN}show queuing interface ethernet1/2/2${NC}"
echo ""
echo "3. BEST WAY - Run traffic and check switch statistics:"
echo "   ${CYAN}bash saturate_cross_esxi.sh 60${NC}"
echo "   Then on switch:"
echo "   ${CYAN}show interface ethernet1/2/2 priority-flow-control${NC}"
echo ""
echo "   You should see:"
echo "   ✓ RxPPP > 0 (switch receiving pause from servers)"
echo "   ✓ TxPPP > 0 (switch sending pause to servers)"
echo "   ✓ MMU drops = 0 or minimal"
echo ""
