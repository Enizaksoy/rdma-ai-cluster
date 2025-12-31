#!/bin/bash

#############################################
# Enable PFC on All Ubuntu RDMA Servers
# Configures lossless RoCE network
#############################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Server list with their RDMA interfaces
SERVERS=(
    "192.168.11.152:ubunturdma1:ens224:rocep19s0"
    "192.168.11.153:ubunturdma2:ens192:rocep11s0"
    "192.168.11.154:ubunturdma3:ens224:rocep19s0"
    "192.168.11.155:ubunturdma4:ens192:rocep11s0"
    "192.168.11.107:ubunturdma5:ens192:rocep11s0"
    "192.168.12.51:ubunturdma6:ens192:rocep11s0"
    "192.168.20.150:ubunturdma7:ens192:rocep11s0"
    "192.168.30.94:ubunturdma8:ens192:rocep11s0"
)

cat > /tmp/ssh_cmd.exp << 'EOF'
#!/usr/bin/expect -f
set ip [lindex $argv 0]
set cmd [lindex $argv 1]
set timeout 30
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
echo "Enable PFC on All RDMA Servers"
echo "========================================"
echo -e "${NC}"
echo "This will configure lossless RoCE by:"
echo "  1. Installing required tools (lldpad)"
echo "  2. Enabling PFC on priority 3"
echo "  3. Configuring RoCE traffic class"
echo ""
echo -e "${RED}WARNING: This requires sudo access!${NC}"
echo ""

# PFC Configuration script to deploy
PFC_SCRIPT='#!/bin/bash
# Enable PFC for RoCE

IFACE=$1

echo "Configuring PFC on $IFACE..."

# Method 1: Using lldpad (standard DCB tool)
if command -v lldptool &> /dev/null; then
    echo "  Using lldpad..."
    sudo lldptool -T -i $IFACE -V PFC enableTx=yes
    sudo lldptool -i $IFACE -T -V PFC -c enabled=0,0,0,1,0,0,0,0
    echo "  ✓ PFC enabled on priority 3"
fi

# Method 2: Using mlnx_qos (Mellanox-specific, more reliable)
if command -v mlnx_qos &> /dev/null; then
    echo "  Using mlnx_qos..."
    sudo mlnx_qos -i $IFACE --pfc 0,0,0,1,0,0,0,0
    echo "  ✓ PFC enabled on priority 3 via mlnx_qos"
fi

# Method 3: Direct sysfs configuration (fallback)
echo "  Configuring via sysfs..."
echo 1 | sudo tee /sys/class/net/$IFACE/ecn/roce_np/enable_pfc > /dev/null 2>&1 || true

# Set traffic class for RoCE (priority 3)
if [ -f /sys/class/infiniband/*/tc/1/traffic_class ]; then
    echo "  Setting RoCE traffic class to 3..."
    echo 3 | sudo tee /sys/class/infiniband/*/tc/1/traffic_class > /dev/null 2>&1 || true
fi

# Verify
echo ""
echo "Current flow control settings:"
sudo ethtool -a $IFACE 2>/dev/null || echo "  (ethtool check failed)"

echo ""
echo "Configuration complete for $IFACE"
'

echo -e "${YELLOW}→ Deploying PFC configuration script to all servers...${NC}"

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname iface rdma_dev <<< "$server_entry"

    echo ""
    echo -e "${BLUE}Configuring $hostname ($iface)...${NC}"

    # Create the script on remote server
    expect /tmp/ssh_cmd.exp "$ip" "cat > /tmp/enable_pfc.sh << 'EOFSCRIPT'
$PFC_SCRIPT
EOFSCRIPT
chmod +x /tmp/enable_pfc.sh" > /dev/null 2>&1

    # Install required packages (skip if already installed)
    echo "  Installing lldpad..."
    expect /tmp/ssh_cmd.exp "$ip" "sudo apt-get update -qq && sudo apt-get install -y -qq lldpad > /dev/null 2>&1" > /dev/null 2>&1 || echo "  (install skipped or failed)"

    # Try to install mlnx-tools (may not be in standard repos)
    expect /tmp/ssh_cmd.exp "$ip" "sudo apt-get install -y -qq mlnx-tools > /dev/null 2>&1" > /dev/null 2>&1 || echo "  (mlnx-tools not available in repos)"

    # Run PFC configuration
    echo "  Enabling PFC..."
    expect /tmp/ssh_cmd.exp "$ip" "sudo bash /tmp/enable_pfc.sh $iface" 2>&1 | grep -E "✓|enabled|Current"

    echo -e "${GREEN}  ✓ $hostname configured${NC}"
done

echo ""
echo -e "${BLUE}========================================"
echo "Verification"
echo "========================================"
echo -e "${NC}"

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname iface rdma_dev <<< "$server_entry"

    echo ""
    echo "$hostname ($iface):"
    expect /tmp/ssh_cmd.exp "$ip" "sudo ethtool -a $iface 2>/dev/null" 2>&1 | grep -E "Pause parameters|RX:|TX:"
done

echo ""
echo -e "${BLUE}========================================"
echo "Next Steps"
echo "========================================"
echo -e "${NC}"
echo ""
echo "1. Verify PFC on switch (should show pause frames now):"
echo "   ssh admin@192.168.50.229"
echo "   show interface ethernet1/2/2 priority-flow-control"
echo ""
echo "2. Run RDMA test again and check for MMU drops:"
echo "   bash saturate_cross_esxi.sh 60"
echo ""
echo "3. Check switch statistics:"
echo "   show queuing interface ethernet1/2/2"
echo "   (should see PFC pause frames, fewer/no MMU drops)"
echo ""
echo "4. IMPORTANT: Make configuration persistent across reboots"
echo "   Create systemd service or add to /etc/network/interfaces"
echo ""

rm -f /tmp/ssh_cmd.exp

echo -e "${GREEN}PFC configuration complete!${NC}"
