#!/bin/bash

#############################################
# Check PFC Configuration on Ubuntu Servers
# Verify if server NICs have PFC enabled
#############################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SERVERS=(
    "192.168.11.152:ubunturdma1:ens224"
    "192.168.11.153:ubunturdma2:ens192"
    "192.168.11.154:ubunturdma3:ens224"
    "192.168.11.155:ubunturdma4:ens192"
    "192.168.11.107:ubunturdma5:ens192"
    "192.168.12.51:ubunturdma6:ens192"
    "192.168.20.150:ubunturdma7:ens192"
    "192.168.30.94:ubunturdma8:ens192"
)

cat > /tmp/ssh_cmd.exp << 'EOF'
#!/usr/bin/expect -f
set ip [lindex $argv 0]
set cmd [lindex $argv 1]
set timeout 10
spawn ssh -o StrictHostKeyChecking=no versa@$ip "$cmd"
expect {
    "password:" {
        send "<PASSWORD>\r"
        exp_continue
    }
    eof
}
EOF
chmod +x /tmp/ssh_cmd.exp

echo -e "${BLUE}========================================"
echo "Server PFC Configuration Check"
echo -e "========================================${NC}"
echo ""

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname iface <<< "$server_entry"

    echo -e "${YELLOW}Checking $hostname ($ip)...${NC}"

    # Check if ethtool exists
    echo "  Interface: $iface"

    # Get PFC settings
    echo -e "${CYAN}  PFC Status:${NC}"
    expect /tmp/ssh_cmd.exp "$ip" "sudo ethtool -a $iface 2>/dev/null | grep -i 'pfc\\|priority'" 2>/dev/null || echo "    (Unable to check - may need sudo)"

    # Check if mlx5_core driver supports PFC
    echo -e "${CYAN}  Driver/Hardware:${NC}"
    expect /tmp/ssh_cmd.exp "$ip" "ethtool -i $iface | grep driver" 2>/dev/null

    # Check current flow control
    echo -e "${CYAN}  Flow Control:${NC}"
    expect /tmp/ssh_cmd.exp "$ip" "ethtool -a $iface 2>/dev/null" 2>/dev/null || echo "    (Unable to check)"

    echo ""
done

echo ""
echo -e "${BLUE}========================================"
echo "Summary"
echo -e "========================================${NC}"
echo ""
echo "To enable PFC on servers, you need:"
echo ""
echo "1. Install mlnx-tools (if using Mellanox/NVIDIA NICs):"
echo "   sudo apt install mstflint mlnx-tools"
echo ""
echo "2. Enable PFC on priority 3 (typical for RoCE):"
echo "   sudo mlnx_qos -i ens224 --pfc 0,0,0,1,0,0,0,0"
echo "   (enables PFC on priority 3 only)"
echo ""
echo "3. Or using dcbtool:"
echo "   sudo dcbtool sc ens224 pfc e:1 a:00100000 w:01111111"
echo ""
echo "4. Verify:"
echo "   sudo mlnx_qos -i ens224"
echo ""

rm -f /tmp/ssh_cmd.exp
