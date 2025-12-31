#!/bin/bash

#############################################
# Network Saturation Test
# Multiple parallel RDMA flows to saturate
# all 10 Gbps switch interfaces
#############################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

DURATION=${1:-60}

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
set timeout 300
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
}

ssh_exec() {
    expect /tmp/ssh_cmd.exp "$1" "$2" 2>/dev/null
}

create_expect_script

print_header "10 Gbps Network Saturation Test"

echo ""
print_info "Test Configuration:"
echo "  Duration: ${DURATION} seconds"
echo "  Parallel RDMA Flows: 8 simultaneous streams"
echo "  Expected Total: 40+ Gbps aggregate"
echo "  Per-Interface: 10-12 Gbps (SATURATED)"
echo ""
echo "This will generate MAXIMUM traffic to stress:"
echo "  • Switch interfaces"
echo "  • Queue depths"
echo "  • PFC pause mechanisms"
echo "  • ECN marking"
echo ""

print_info ">>> GO TO YOUR SWITCH NOW AND START MONITORING <<<"
echo ""

sleep 3

print_header "Starting 8 Parallel RDMA Flows"

echo ""
print_info "Flow Configuration:"
echo "  1. ubunturdma1 → ubunturdma3 (Vlan251, Port Eth1/2/2)"
echo "  2. ubunturdma3 → ubunturdma1 (Vlan251, Port Eth1/2/2)"
echo "  3. ubunturdma6 → ubunturdma8 (Vlan251, Ports Eth1/1/2, Eth1/1/1)"
echo "  4. ubunturdma8 → ubunturdma6 (Vlan251, Ports Eth1/1/1, Eth1/1/2)"
echo "  5. ubunturdma2 → ubunturdma4 (Vlan250, Port Eth1/2/1)"
echo "  6. ubunturdma4 → ubunturdma2 (Vlan250, Port Eth1/2/1)"
echo "  7. ubunturdma5 → ubunturdma7 (Vlan250, Port Eth1/1/1)"
echo "  8. ubunturdma7 → ubunturdma5 (Vlan250, Port Eth1/1/1)"
echo ""

print_info "Starting RDMA servers..."

# Start all servers
expect /tmp/ssh_cmd.exp "192.168.11.154" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely" &
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.152" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely" &
sleep 1
expect /tmp/ssh_cmd.exp "192.168.30.94" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &
sleep 1
expect /tmp/ssh_cmd.exp "192.168.12.51" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.155" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.153" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &
sleep 1
expect /tmp/ssh_cmd.exp "192.168.20.150" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.107" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &

sleep 5

print_info "Starting RDMA clients..."

# Start all clients
ssh_exec "192.168.11.152" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely 192.168.251.113" &
sleep 1
ssh_exec "192.168.11.154" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely 192.168.251.111" &
sleep 1
ssh_exec "192.168.12.51" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.118" &
sleep 1
ssh_exec "192.168.30.94" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.116" &
sleep 1
ssh_exec "192.168.11.153" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.250.114" &
sleep 1
ssh_exec "192.168.11.155" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.250.112" &
sleep 1
ssh_exec "192.168.11.107" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.250.117" &
sleep 1
ssh_exec "192.168.20.150" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.250.115" &

echo ""
print_success "All 8 parallel flows launched!"
echo ""
print_info ">>> SWITCH IS NOW UNDER MAXIMUM LOAD <<<"
echo ""
echo "Monitor these switch ports NOW:"
echo "  • Eth1/1/1 - Should see 10+ Gbps"
echo "  • Eth1/1/2 - Should see 6+ Gbps"
echo "  • Eth1/2/1 - Should see 10+ Gbps"
echo "  • Eth1/2/2 - Should see 10+ Gbps"
echo ""
echo "Check for:"
echo "  • Queue depths approaching 100%"
echo "  • PFC pause frames being sent"
echo "  • ECN marks on packets"
echo "  • No packet drops (PFC should prevent)"
echo ""

print_info "Running for ${DURATION} seconds..."

# Wait for all to complete
wait

echo ""
print_header "Network Saturation Test Complete"

echo ""
print_success "Test completed successfully!"
echo ""
echo "Expected Results:"
echo "  • Total throughput: 40-50 Gbps aggregate"
echo "  • Per-interface: 10-12 Gbps (saturated)"
echo "  • Switch should have shown:"
echo "    - High queue utilization"
echo "    - Active PFC (if configured)"
echo "    - ECN marking (if configured)"
echo "    - Minimal drops"
echo ""

rm -f /tmp/ssh_cmd.exp

print_header "Test Finished"
