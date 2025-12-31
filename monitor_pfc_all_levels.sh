#!/bin/bash

#############################################
# Monitor PFC/Pause Frames at All Levels
# - ESXi hosts
# - Ubuntu servers
# - Cisco switch
#############################################

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

DURATION=${1:-30}
ESXI1_IP="192.168.50.152"
ESXI1_PASS="<PASSWORD>"
SWITCH_IP="192.168.50.229"
SWITCH_PASS="<PASSWORD>"

echo -e "${BLUE}========================================${NC}"
echo "Multi-Level PFC Monitoring"
echo "Duration: ${DURATION} seconds"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check ESXi pause frames
check_esxi_pause() {
    local esxi_ip=$1
    local esxi_pass=$2
    local vmnic=$3

    /usr/bin/expect << EOFEXP 2>&1 | grep -E "rxPauseCtrlPhy|txPauseCtrlPhy|rx_global_pause|tx_global_pause"
set timeout 10
spawn ssh -o StrictHostKeyChecking=no root@${esxi_ip}
expect "Password:"
send "${esxi_pass}\r"
expect "~]"
send "vsish -e cat /net/pNics/${vmnic}/stats | grep -i pause\r"
expect "~]"
send "exit\r"
expect eof
EOFEXP
}

# Function to check switch PFC
check_switch_pfc() {
    local port=$1

    /usr/bin/expect << EOFEXP 2>&1 | grep -E "RxPPP|TxPPP|Ethernet"
set timeout 10
spawn ssh -o StrictHostKeyChecking=no admin@${SWITCH_IP}
expect "Password:"
send "${SWITCH_PASS}\r"
expect "#"
send "show interface ${port} priority-flow-control\r"
expect "#"
send "exit\r"
expect eof
EOFEXP
}

echo -e "${YELLOW}=== BEFORE Traffic Test ===${NC}"
echo ""

echo -e "${CYAN}ESXi Host 1 - vmnic3:${NC}"
check_esxi_pause "$ESXI1_IP" "$ESXI1_PASS" "vmnic3"

echo ""
echo -e "${CYAN}ESXi Host 1 - vmnic4:${NC}"
check_esxi_pause "$ESXI1_IP" "$ESXI1_PASS" "vmnic4"

echo ""
echo -e "${CYAN}Switch - Ethernet1/2/2:${NC}"
check_switch_pfc "ethernet1/2/2"

echo ""
echo -e "${YELLOW}=== Starting Traffic Test (${DURATION} seconds) ===${NC}"
echo ""

# Start traffic test in background
bash /mnt/c/Users/eniza/Documents/claudechats/saturate_cross_esxi.sh $DURATION > /tmp/traffic_test.log 2>&1 &
TRAFFIC_PID=$!

# Wait 10 seconds for traffic to ramp up
sleep 10

echo -e "${YELLOW}=== DURING Traffic (10 seconds in) ===${NC}"
echo ""

echo -e "${CYAN}ESXi Host 1 - vmnic3:${NC}"
check_esxi_pause "$ESXI1_IP" "$ESXI1_PASS" "vmnic3"

echo ""
echo -e "${CYAN}ESXi Host 1 - vmnic4:${NC}"
check_esxi_pause "$ESXI1_IP" "$ESXI1_PASS" "vmnic4"

echo ""
echo -e "${CYAN}Switch - Ethernet1/2/2:${NC}"
check_switch_pfc "ethernet1/2/2"

echo ""
echo -e "${CYAN}Switch - Ethernet1/2/1:${NC}"
check_switch_pfc "ethernet1/2/1"

# Wait for traffic test to complete
wait $TRAFFIC_PID

sleep 2

echo ""
echo -e "${YELLOW}=== AFTER Traffic Test ===${NC}"
echo ""

echo -e "${CYAN}ESXi Host 1 - vmnic3:${NC}"
check_esxi_pause "$ESXI1_IP" "$ESXI1_PASS" "vmnic3"

echo ""
echo -e "${CYAN}ESXi Host 1 - vmnic4:${NC}"
check_esxi_pause "$ESXI1_IP" "$ESXI1_PASS" "vmnic4"

echo ""
echo -e "${CYAN}Switch - Ethernet1/2/2:${NC}"
check_switch_pfc "ethernet1/2/2"

echo ""
echo -e "${BLUE}========================================${NC}"
echo "Monitoring Complete"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Key Metrics to Check:"
echo ""
echo "ESXi Hosts:"
echo "  rxPauseCtrlPhy: Should be > 0 (receiving pause from switch)"
echo "  txPauseCtrlPhy: Should be > 0 (sending pause to switch)"
echo ""
echo "Cisco Switch:"
echo "  RxPPP: Should be > 0 (receiving pause from servers)"
echo "  TxPPP: Should be > 0 (sending pause to servers)"
echo ""
echo "If all counters are still 0:"
echo "  - Check that traffic is using RDMA interfaces"
echo "  - Verify priority 3 is configured for RoCE traffic"
echo "  - Check QoS mapping on servers and switch"
echo ""
