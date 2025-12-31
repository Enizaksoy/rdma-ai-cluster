#!/bin/bash

#############################################
# Cross-VLAN RDMA Bandwidth Test
# Source and destination on different VLANs
# to generate traffic visible on switch
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

print_header "Cross-VLAN RDMA Bandwidth Test"

OUTPUT_FILE="/mnt/c/Users/eniza/Documents/claudechats/rdma_crossvlan_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$OUTPUT_FILE")

echo ""
echo "Testing RDMA bandwidth across VLANs"
echo "Results saved to: $OUTPUT_FILE"
echo ""

#############################################
# Test 1: Vlan251 -> Vlan250
#############################################
print_info "Test 1: Vlan251 (ubunturdma1) → Vlan250 (ubunturdma2)"
echo "  Source: ubunturdma1 (192.168.251.111) - Vlan251"
echo "  Target: ubunturdma2 (192.168.250.112) - Vlan250"
echo "  >>> Traffic will cross VLANs - visible on switch! <<<"
echo ""

SERVER1_MGMT="192.168.11.152"
SERVER2_MGMT="192.168.11.153"
SERVER2_RDMA="192.168.250.112"

# Get RDMA device names
print_info "Detecting RDMA devices..."
DEVICE1=$(ssh_exec "$SERVER1_MGMT" "ibv_devices | grep roce | head -1 | awk '{print \$1}'")
DEVICE2=$(ssh_exec "$SERVER2_MGMT" "ibv_devices | grep roce | head -1 | awk '{print \$1}'")

DEVICE1=$(echo $DEVICE1 | tr -d '\r\n' | awk '{print $NF}')
DEVICE2=$(echo $DEVICE2 | tr -d '\r\n' | awk '{print $NF}')

echo "  Device 1: $DEVICE1 (on Vlan251)"
echo "  Device 2: $DEVICE2 (on Vlan250)"
echo ""

# Start server
print_info "Starting RDMA server on ubunturdma2 (Vlan250)..."
expect /tmp/ssh_cmd.exp "$SERVER2_MGMT" "ib_write_bw -d $DEVICE2 -D 20" > /tmp/server_output.txt 2>&1 &
SERVER_PID=$!

sleep 3

# Run client
print_info "Running RDMA client from ubunturdma1 (Vlan251)..."
print_info ">>> MONITOR YOUR SWITCH NOW - Cross-VLAN traffic! <<<"
echo ""

CLIENT_OUTPUT=$(ssh_exec "$SERVER1_MGMT" "ib_write_bw -d $DEVICE1 -D 20 $SERVER2_RDMA")

echo "Bandwidth Results:"
echo "$CLIENT_OUTPUT" | grep -E "65536.*[0-9]+" | tail -1

# Extract bandwidth
BANDWIDTH=$(echo "$CLIENT_OUTPUT" | grep "65536" | tail -1 | awk '{print $4}')
echo ""
print_success "Cross-VLAN (251→250) Bandwidth: $BANDWIDTH MB/sec"

wait $SERVER_PID 2>/dev/null
sleep 2

#############################################
# Test 2: Vlan250 -> Vlan251
#############################################
echo ""
print_info "Test 2: Vlan250 (ubunturdma4) → Vlan251 (ubunturdma6)"
echo "  Source: ubunturdma4 (192.168.250.114) - Vlan250"
echo "  Target: ubunturdma6 (192.168.251.116) - Vlan251"
echo "  >>> Traffic will cross VLANs - visible on switch! <<<"
echo ""

SERVER1_MGMT="192.168.11.155"
SERVER2_MGMT="192.168.12.51"
SERVER2_RDMA="192.168.251.116"

# Get RDMA device names
DEVICE1=$(ssh_exec "$SERVER1_MGMT" "ibv_devices | grep roce | head -1 | awk '{print \$1}'")
DEVICE2=$(ssh_exec "$SERVER2_MGMT" "ibv_devices | grep roce | head -1 | awk '{print \$1}'")

DEVICE1=$(echo $DEVICE1 | tr -d '\r\n' | awk '{print $NF}')
DEVICE2=$(echo $DEVICE2 | tr -d '\r\n' | awk '{print $NF}')

echo "  Device 1: $DEVICE1 (on Vlan250)"
echo "  Device 2: $DEVICE2 (on Vlan251)"
echo ""

# Start server
print_info "Starting RDMA server on ubunturdma6 (Vlan251)..."
expect /tmp/ssh_cmd.exp "$SERVER2_MGMT" "ib_write_bw -d $DEVICE2 -D 20" > /tmp/server_output.txt 2>&1 &
SERVER_PID=$!

sleep 3

# Run client
print_info "Running RDMA client from ubunturdma4 (Vlan250)..."
print_info ">>> MONITOR YOUR SWITCH NOW - Cross-VLAN traffic! <<<"
echo ""

CLIENT_OUTPUT=$(ssh_exec "$SERVER1_MGMT" "ib_write_bw -d $DEVICE1 -D 20 $SERVER2_RDMA")

echo "Bandwidth Results:"
echo "$CLIENT_OUTPUT" | grep -E "65536.*[0-9]+" | tail -1

# Extract bandwidth
BANDWIDTH=$(echo "$CLIENT_OUTPUT" | grep "65536" | tail -1 | awk '{print $4}')
echo ""
print_success "Cross-VLAN (250→251) Bandwidth: $BANDWIDTH MB/sec"

wait $SERVER_PID 2>/dev/null

#############################################
# Test 3: Multiple simultaneous cross-VLAN flows
#############################################
echo ""
print_header "Test 3: Multiple Simultaneous Cross-VLAN Flows"
echo ""
print_info "Starting 4 simultaneous cross-VLAN flows..."
print_info "This will generate HEAVY traffic across VLANs!"
echo ""
echo "Flows:"
echo "  1. ubunturdma1 (251) → ubunturdma2 (250)"
echo "  2. ubunturdma3 (251) → ubunturdma5 (250)"
echo "  3. ubunturdma4 (250) → ubunturdma6 (251)"
echo "  4. ubunturdma7 (250) → ubunturdma8 (251)"
echo ""
print_info ">>> MAXIMUM SWITCH LOAD - Monitor all VLAN interfaces! <<<"
echo ""

sleep 2

# Start servers
echo "Starting RDMA servers..."
expect /tmp/ssh_cmd.exp "192.168.11.153" "ib_write_bw -d rocep11s0 -D 15" &
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.107" "ib_write_bw -d rocep11s0 -D 15" &
sleep 1
expect /tmp/ssh_cmd.exp "192.168.12.51" "ib_write_bw -d rocep11s0 -D 15" &
sleep 1
expect /tmp/ssh_cmd.exp "192.168.30.94" "ib_write_bw -d rocep11s0 -D 15" &

sleep 4

# Start clients
echo "Starting RDMA clients..."
ssh_exec "192.168.11.152" "ib_write_bw -d rocep19s0 -D 15 192.168.250.112" &
sleep 1
ssh_exec "192.168.11.154" "ib_write_bw -d rocep19s0 -D 15 192.168.250.115" &
sleep 1
ssh_exec "192.168.11.155" "ib_write_bw -d rocep11s0 -D 15 192.168.251.116" &
sleep 1
ssh_exec "192.168.20.150" "ib_write_bw -d rocep11s0 -D 15 192.168.251.118" &

echo ""
print_success "4 simultaneous flows running for 15 seconds!"
print_info "Check your switch NOW for:"
echo "  - Queue depths on VLAN interfaces"
echo "  - PFC pause frames"
echo "  - ECN marked packets"
echo "  - Inter-VLAN routing load"
echo ""

# Wait for completion
wait

echo ""
print_success "Multiple flow test completed!"

#############################################
# Summary
#############################################
echo ""
print_header "Cross-VLAN RDMA Test Complete"

echo ""
echo "Summary:"
echo "  ✓ Test 1: Vlan251 → Vlan250 (single flow)"
echo "  ✓ Test 2: Vlan250 → Vlan251 (single flow)"
echo "  ✓ Test 3: 4 simultaneous cross-VLAN flows"
echo ""
echo "What you should have seen on switch:"
echo "  • Traffic between VLAN 251 and 250 interfaces"
echo "  • Inter-VLAN routing activity"
echo "  • Queue utilization on both VLANs"
echo "  • Possible PFC/ECN activity during multi-flow test"
echo ""
echo "Results saved to: $OUTPUT_FILE"
echo ""

# Cleanup
rm -f /tmp/ssh_cmd.exp /tmp/server_output.txt

echo -e "${BLUE}========================================${NC}"
