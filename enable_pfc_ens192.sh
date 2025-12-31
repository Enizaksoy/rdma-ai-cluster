#!/bin/bash

#############################################
# Enable PFC on ens192 for All 8 Servers
# Shows all commands being executed
#############################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# All 8 servers - using ens192 only
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

IFACE="ens192"

cat > /tmp/ssh_cmd.exp << 'EOF'
#!/usr/bin/expect -f
set ip [lindex $argv 0]
set cmd [lindex $argv 1]
set timeout 60
spawn ssh -o StrictHostKeyChecking=no versa@$ip "$cmd"
expect {
    "password:" {
        send "Versa@123!!\r"
        exp_continue
    }
    eof
}
EOF
chmod +x /tmp/ssh_cmd.exp

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_cmd() {
    echo -e "${CYAN}[CMD] $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_header "Enable PFC on ens192 - All 8 Servers"

echo ""
echo "Interface: $IFACE (all servers)"
echo "Priority: 3 (for RoCE/RDMA)"
echo "Method: lldpad + ethtool"
echo ""

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname <<< "$server_entry"

    print_header "$hostname ($ip)"

    echo ""
    echo -e "${YELLOW}Step 1: Install lldpad${NC}"
    print_cmd "ssh $hostname 'sudo apt-get update && sudo apt-get install -y lldpad'"
    expect /tmp/ssh_cmd.exp "$ip" "sudo apt-get update -qq 2>&1 && sudo apt-get install -y lldpad 2>&1" 2>&1 | tail -5
    print_success "lldpad installed"

    echo ""
    echo -e "${YELLOW}Step 2: Start lldpad service${NC}"
    print_cmd "ssh $hostname 'sudo systemctl start lldpad'"
    expect /tmp/ssh_cmd.exp "$ip" "sudo systemctl start lldpad 2>&1" 2>&1
    print_cmd "ssh $hostname 'sudo systemctl enable lldpad'"
    expect /tmp/ssh_cmd.exp "$ip" "sudo systemctl enable lldpad 2>&1" 2>&1
    print_success "lldpad service started and enabled"

    echo ""
    echo -e "${YELLOW}Step 3: Enable PFC on $IFACE${NC}"
    print_cmd "ssh $hostname 'sudo lldptool -T -i $IFACE -V PFC enableTx=yes'"
    expect /tmp/ssh_cmd.exp "$ip" "sudo lldptool -T -i $IFACE -V PFC enableTx=yes 2>&1" 2>&1

    print_cmd "ssh $hostname 'sudo lldptool -i $IFACE -T -V PFC -c enabled=0,0,0,1,0,0,0,0'"
    expect /tmp/ssh_cmd.exp "$ip" "sudo lldptool -i $IFACE -T -V PFC -c enabled=0,0,0,1,0,0,0,0 2>&1" 2>&1
    print_success "PFC enabled on priority 3"

    echo ""
    echo -e "${YELLOW}Step 4: Configure DCB (Data Center Bridging)${NC}"
    print_cmd "ssh $hostname 'sudo lldptool set-lldp -i $IFACE adminStatus=rxtx'"
    expect /tmp/ssh_cmd.exp "$ip" "sudo lldptool set-lldp -i $IFACE adminStatus=rxtx 2>&1" 2>&1
    print_success "DCB configured"

    echo ""
    echo -e "${YELLOW}Step 5: Verify PFC configuration${NC}"
    print_cmd "ssh $hostname 'sudo ethtool -a $IFACE'"
    expect /tmp/ssh_cmd.exp "$ip" "sudo ethtool -a $IFACE 2>&1" 2>&1

    print_cmd "ssh $hostname 'sudo lldptool -t -i $IFACE -V PFC'"
    expect /tmp/ssh_cmd.exp "$ip" "sudo lldptool -t -i $IFACE -V PFC 2>&1" 2>&1 | head -10

    print_success "$hostname configuration complete!"

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    sleep 2
done

print_header "Configuration Summary"

echo ""
echo "Commands executed on each server:"
echo ""
echo "1. sudo apt-get update && sudo apt-get install -y lldpad"
echo "2. sudo systemctl start lldpad"
echo "3. sudo systemctl enable lldpad"
echo "4. sudo lldptool -T -i ens192 -V PFC enableTx=yes"
echo "5. sudo lldptool -i ens192 -T -V PFC -c enabled=0,0,0,1,0,0,0,0"
echo "6. sudo lldptool set-lldp -i ens192 adminStatus=rxtx"
echo "7. sudo ethtool -a ens192  # Verify"
echo ""

print_header "Final Verification - All Servers"

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname <<< "$server_entry"

    echo ""
    echo -e "${CYAN}$hostname ($ip) - ens192:${NC}"
    expect /tmp/ssh_cmd.exp "$ip" "sudo ethtool -a $IFACE 2>&1" 2>&1 | grep -E "Pause parameters|RX:|TX:"
done

echo ""
print_header "Next Steps"

echo ""
echo "1. Check switch for PFC pause frames:"
echo "   ssh admin@192.168.50.229"
echo "   show interface ethernet1/2/2 priority-flow-control"
echo ""
echo "2. Run traffic test:"
echo "   bash saturate_cross_esxi.sh 60"
echo ""
echo "3. Verify NO MMU drops:"
echo "   On switch: show queuing interface ethernet1/2/2"
echo "   Look for: Ingress MMU Drop Pkts should be 0 or minimal"
echo ""
echo "4. You should now see:"
echo "   ✓ RxPPP > 0 (switch receiving pause frames from servers)"
echo "   ✓ TxPPP > 0 (switch sending pause frames to servers)"
echo "   ✓ MMU drops = 0 or very low"
echo "   ✓ Lossless RDMA network!"
echo ""

rm -f /tmp/ssh_cmd.exp

print_success "PFC configuration complete on all 8 servers (ens192)!"
