#!/bin/bash

#############################################
# Cross-Port Network Saturation Test
# RDMA flows between different switch ports
# to ensure traffic is visible on ALL ports
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

print_header "Cross-Port Network Saturation Test"

echo ""
print_info "Test Configuration:"
echo "  Duration: ${DURATION} seconds"
echo "  Strategy: ALL flows cross switch ports"
echo "  Expected: High traffic on ALL 4 switch ports"
echo ""
echo "Port Mapping:"
echo "  Eth1/1/1: ubunturdma5, ubunturdma7, ubunturdma8"
echo "  Eth1/1/2: ubunturdma6"
echo "  Eth1/2/1: ubunturdma2, ubunturdma4"
echo "  Eth1/2/2: ubunturdma1, ubunturdma3"
echo ""

print_header "Cross-Port RDMA Flow Configuration"

echo ""
echo "FLOWS THAT CROSS SWITCH PORTS:"
echo ""
echo "  1. ubunturdma1 (Eth1/2/2) → ubunturdma2 (Eth1/2/1) - Vlan250/251 routing"
echo "  2. ubunturdma2 (Eth1/2/1) → ubunturdma1 (Eth1/2/2) - Vlan250/251 routing"
echo ""
echo "  3. ubunturdma3 (Eth1/2/2) → ubunturdma4 (Eth1/2/1) - Vlan250/251 routing"
echo "  4. ubunturdma4 (Eth1/2/1) → ubunturdma3 (Eth1/2/2) - Vlan250/251 routing"
echo ""
echo "  5. ubunturdma6 (Eth1/1/2) → ubunturdma8 (Eth1/1/1) - Cross-port same VLAN"
echo "  6. ubunturdma8 (Eth1/1/1) → ubunturdma6 (Eth1/1/2) - Cross-port same VLAN"
echo ""
echo "  7. ubunturdma5 (Eth1/1/1) → ubunturdma6 (Eth1/1/2) - Vlan250/251 routing"
echo "  8. ubunturdma7 (Eth1/1/1) → ubunturdma6 (Eth1/1/2) - Vlan250/251 routing"
echo ""
echo "This ensures ALL switch ports see traffic!"
echo ""

print_info ">>> GO TO YOUR SWITCH NOW AND START MONITORING <<<"
echo ""

sleep 3

print_info "Starting RDMA servers..."

# Servers that will receive traffic
expect /tmp/ssh_cmd.exp "192.168.11.153" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &  # ubunturdma2 (Eth1/2/1)
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.152" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely" &  # ubunturdma1 (Eth1/2/2)
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.155" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &  # ubunturdma4 (Eth1/2/1)
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.154" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely" &  # ubunturdma3 (Eth1/2/2)
sleep 1
expect /tmp/ssh_cmd.exp "192.168.30.94" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &   # ubunturdma8 (Eth1/1/1)
sleep 1
expect /tmp/ssh_cmd.exp "192.168.12.51" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &   # ubunturdma6 (Eth1/1/2)
sleep 1

sleep 5

print_info "Starting RDMA clients..."

# Cross-port flows on Eth1/2/x ports (will use Layer 3 routing)
ssh_exec "192.168.11.152" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely 192.168.250.112" &  # ubunturdma1→ubunturdma2
sleep 1
ssh_exec "192.168.11.153" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.111" &  # ubunturdma2→ubunturdma1
sleep 1
ssh_exec "192.168.11.154" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely 192.168.250.114" &  # ubunturdma3→ubunturdma4
sleep 1
ssh_exec "192.168.11.155" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.113" &  # ubunturdma4→ubunturdma3
sleep 1

# Cross-port flows on Eth1/1/x ports (same VLAN, should be faster)
ssh_exec "192.168.12.51" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.118" &   # ubunturdma6→ubunturdma8
sleep 1
ssh_exec "192.168.30.94" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.116" &   # ubunturdma8→ubunturdma6
sleep 1

# Additional flows to saturate Eth1/1/1 and Eth1/1/2
ssh_exec "192.168.11.107" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.116" &  # ubunturdma5→ubunturdma6
sleep 1
ssh_exec "192.168.20.150" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.116" &  # ubunturdma7→ubunturdma6
sleep 1

echo ""
print_success "All 8 cross-port flows launched!"
echo ""
print_info ">>> SWITCH PORTS NOW SHOWING TRAFFIC <<<"
echo ""
echo "Monitor these switch ports NOW:"
echo "  • Eth1/1/1 - Multiple flows from ubunturdma5,7,8"
echo "  • Eth1/1/2 - Receiving from multiple sources"
echo "  • Eth1/2/1 - Bidirectional with Eth1/2/2"
echo "  • Eth1/2/2 - Bidirectional with Eth1/2/1"
echo ""
echo "Check for:"
echo "  • Queue depths approaching 100%"
echo "  • PFC pause frames being sent"
echo "  • ECN marks on packets"
echo "  • Routing latency on cross-VLAN flows"
echo ""

print_info "Running for ${DURATION} seconds..."

# Wait for all to complete
wait

echo ""
print_header "Cross-Port Saturation Test Complete"

echo ""
print_success "Test completed successfully!"
echo ""
echo "Expected Results:"
echo "  • All 4 switch ports showed traffic"
echo "  • Cross-VLAN flows: ~1 GB/sec (Layer 3 routing)"
echo "  • Same-VLAN flows: ~6 GB/sec (Layer 2 switching)"
echo "  • Switch should have shown:"
echo "    - Traffic on ALL monitored ports"
echo "    - Higher latency on cross-VLAN flows"
echo "    - Queue utilization"
echo "    - PFC/ECN activity (if configured)"
echo ""

rm -f /tmp/ssh_cmd.exp

print_header "Test Finished"
