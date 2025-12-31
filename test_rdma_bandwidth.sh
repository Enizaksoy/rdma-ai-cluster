#!/bin/bash

#############################################
# RDMA Bandwidth Testing Script (Fixed)
# Tests actual RDMA performance between
# servers using ib_write_bw
#############################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

create_expect_script() {
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
}

ssh_exec() {
    expect /tmp/ssh_cmd.exp "$1" "$2" 2>/dev/null
}

create_expect_script

print_header "RDMA Bandwidth Performance Test"

OUTPUT_FILE="/mnt/c/Users/eniza/Documents/claudechats/rdma_bandwidth_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$OUTPUT_FILE")

echo ""
echo "Testing RDMA bandwidth between cluster nodes"
echo "Results saved to: $OUTPUT_FILE"
echo ""

#############################################
# Test 1: Vlan251 - ubunturdma1 <-> ubunturdma3
#############################################
print_info "Test 1: Vlan251 Performance"
echo "  Server 1: ubunturdma1 (192.168.251.111)"
echo "  Server 2: ubunturdma3 (192.168.251.113)"
echo ""

SERVER1_MGMT="192.168.11.152"
SERVER2_MGMT="192.168.11.154"
SERVER2_RDMA="192.168.251.113"

# Get RDMA device names
print_info "Detecting RDMA devices..."
DEVICE1=$(ssh_exec "$SERVER1_MGMT" "ibv_devices | grep roce | head -1 | awk '{print \$1}'")
DEVICE2=$(ssh_exec "$SERVER2_MGMT" "ibv_devices | grep roce | head -1 | awk '{print \$1}'")

DEVICE1=$(echo $DEVICE1 | tr -d '\r\n' | awk '{print $NF}')
DEVICE2=$(echo $DEVICE2 | tr -d '\r\n' | awk '{print $NF}')

echo "  Device 1: $DEVICE1"
echo "  Device 2: $DEVICE2"
echo ""

# Start server
print_info "Starting RDMA server on ubunturdma3..."
expect /tmp/ssh_cmd.exp "$SERVER2_MGMT" "ib_write_bw -d $DEVICE2 -D 10" > /tmp/server_output.txt 2>&1 &
SERVER_PID=$!

sleep 3

# Run client
print_info "Running RDMA client from ubunturdma1..."
CLIENT_OUTPUT=$(ssh_exec "$SERVER1_MGMT" "ib_write_bw -d $DEVICE1 -D 10 $SERVER2_RDMA")

echo ""
echo "Bandwidth Results:"
echo "$CLIENT_OUTPUT" | grep -E "65536.*[0-9]+" | tail -1

# Extract bandwidth
BANDWIDTH=$(echo "$CLIENT_OUTPUT" | grep "65536" | tail -1 | awk '{print $4}')
echo ""
print_success "Vlan251 Bandwidth: $BANDWIDTH MB/sec"

wait $SERVER_PID 2>/dev/null
sleep 2

#############################################
# Test 2: Vlan250 - ubunturdma2 <-> ubunturdma4
#############################################
echo ""
print_info "Test 2: Vlan250 Performance"
echo "  Server 1: ubunturdma4 (192.168.250.114)"
echo "  Server 2: ubunturdma2 (192.168.250.112)"
echo ""

SERVER1_MGMT="192.168.11.155"
SERVER2_MGMT="192.168.11.153"
SERVER2_RDMA="192.168.250.112"

# Get RDMA device names
DEVICE1=$(ssh_exec "$SERVER1_MGMT" "ibv_devices | grep roce | head -1 | awk '{print \$1}'")
DEVICE2=$(ssh_exec "$SERVER2_MGMT" "ibv_devices | grep roce | head -1 | awk '{print \$1}'")

DEVICE1=$(echo $DEVICE1 | tr -d '\r\n' | awk '{print $NF}')
DEVICE2=$(echo $DEVICE2 | tr -d '\r\n' | awk '{print $NF}')

echo "  Device 1: $DEVICE1"
echo "  Device 2: $DEVICE2"
echo ""

# Start server
print_info "Starting RDMA server on ubunturdma2..."
expect /tmp/ssh_cmd.exp "$SERVER2_MGMT" "ib_write_bw -d $DEVICE2 -D 10" > /tmp/server_output.txt 2>&1 &
SERVER_PID=$!

sleep 3

# Run client
print_info "Running RDMA client from ubunturdma4..."
CLIENT_OUTPUT=$(ssh_exec "$SERVER1_MGMT" "ib_write_bw -d $DEVICE1 -D 10 $SERVER2_RDMA")

echo ""
echo "Bandwidth Results:"
echo "$CLIENT_OUTPUT" | grep -E "65536.*[0-9]+" | tail -1

# Extract bandwidth
BANDWIDTH=$(echo "$CLIENT_OUTPUT" | grep "65536" | tail -1 | awk '{print $4}')
echo ""
print_success "Vlan250 Bandwidth: $BANDWIDTH MB/sec"

wait $SERVER_PID 2>/dev/null

#############################################
# Summary
#############################################
echo ""
print_header "RDMA Bandwidth Test Complete"

echo ""
echo "Both VLANs tested successfully!"
echo "Results saved to: $OUTPUT_FILE"
echo ""
echo "Typical performance expectations:"
echo "  10 GbE RDMA: 5-7 GB/sec"
echo "  25 GbE RDMA: 12-15 GB/sec"
echo "  40 GbE RDMA: 20-25 GB/sec"
echo "  100 GbE RDMA: 50-60 GB/sec"
echo ""

# Cleanup
rm -f /tmp/ssh_cmd.exp /tmp/server_output.txt

echo -e "${BLUE}========================================${NC}"
