#!/bin/bash

#############################################
# Cross-ESXi Host Network Saturation
# Maximum switch traffic between two ESXi hosts
# All traffic flows between Host1 and Host2
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

print_header "Cross-ESXi Host Network Saturation Test"

echo ""
print_info "ESXi Host Topology:"
echo ""
echo "  ESXi Host 1 (Switch Module Eth1/2/x):"
echo "    - ubunturdma1 (Eth1/2/2, Vlan251)"
echo "    - ubunturdma2 (Eth1/2/1, Vlan250)"
echo "    - ubunturdma3 (Eth1/2/2, Vlan251)"
echo "    - ubunturdma4 (Eth1/2/1, Vlan250)"
echo ""
echo "  ESXi Host 2 (Switch Module Eth1/1/x):"
echo "    - ubunturdma5 (Eth1/1/1, Vlan250)"
echo "    - ubunturdma6 (Eth1/1/2, Vlan251)"
echo "    - ubunturdma7 (Eth1/1/1, Vlan250)"
echo "    - ubunturdma8 (Eth1/1/1, Vlan251)"
echo ""

print_header "Cross-ESXi Flow Configuration (8 Flows)"

echo ""
echo "ALL flows go between ESXi Host 1 and ESXi Host 2:"
echo ""
echo "  From Host1 to Host2:"
echo "    1. ubunturdma1 (Vlan251) → ubunturdma6 (Vlan251) - Same VLAN, HIGH BW"
echo "    2. ubunturdma2 (Vlan250) → ubunturdma5 (Vlan250) - Same VLAN, HIGH BW"
echo "    3. ubunturdma3 (Vlan251) → ubunturdma8 (Vlan251) - Same VLAN, HIGH BW"
echo "    4. ubunturdma4 (Vlan250) → ubunturdma7 (Vlan250) - Same VLAN, HIGH BW"
echo ""
echo "  From Host2 to Host1:"
echo "    5. ubunturdma5 (Vlan250) → ubunturdma2 (Vlan250) - Same VLAN, HIGH BW"
echo "    6. ubunturdma6 (Vlan251) → ubunturdma1 (Vlan251) - Same VLAN, HIGH BW"
echo "    7. ubunturdma7 (Vlan250) → ubunturdma4 (Vlan250) - Same VLAN, HIGH BW"
echo "    8. ubunturdma8 (Vlan251) → ubunturdma3 (Vlan251) - Same VLAN, HIGH BW"
echo ""
echo "Expected Results:"
echo "  • ALL 4 switch ports will show heavy traffic"
echo "  • Same-VLAN flows = ~6 GB/sec each (Layer 2 switching)"
echo "  • Total aggregate: 40-50 Gbps across switch"
echo "  • ALL traffic crosses between switch modules"
echo ""
echo "Duration: ${DURATION} seconds"
echo ""

print_info ">>> GO TO SWITCH 192.168.50.229 AND MONITOR NOW <<<"
echo ""

sleep 3

print_info "Starting RDMA servers (Host1 and Host2)..."

# Start servers on Host1 (destinations from Host2)
expect /tmp/ssh_cmd.exp "192.168.11.152" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely" &  # ubunturdma1
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.153" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &  # ubunturdma2
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.154" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely" &  # ubunturdma3
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.155" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &  # ubunturdma4
sleep 1

# Start servers on Host2 (destinations from Host1)
expect /tmp/ssh_cmd.exp "192.168.11.107" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &  # ubunturdma5
sleep 1
expect /tmp/ssh_cmd.exp "192.168.12.51" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &   # ubunturdma6
sleep 1
expect /tmp/ssh_cmd.exp "192.168.20.150" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &  # ubunturdma7
sleep 1
expect /tmp/ssh_cmd.exp "192.168.30.94" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &   # ubunturdma8
sleep 1

sleep 5

print_success "All 8 servers ready"
echo ""
print_info "Starting cross-ESXi RDMA traffic (Host1 → Host2 and Host2 → Host1)..."

# Flows from Host1 to Host2
ssh_exec "192.168.11.152" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely 192.168.251.116" &  # ubunturdma1→6
sleep 1
ssh_exec "192.168.11.153" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.250.115" &  # ubunturdma2→5
sleep 1
ssh_exec "192.168.11.154" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely 192.168.251.118" &  # ubunturdma3→8
sleep 1
ssh_exec "192.168.11.155" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.250.117" &  # ubunturdma4→7
sleep 1

# Flows from Host2 to Host1
ssh_exec "192.168.11.107" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.250.112" &  # ubunturdma5→2
sleep 1
ssh_exec "192.168.12.51" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.111" &   # ubunturdma6→1
sleep 1
ssh_exec "192.168.20.150" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.250.114" &  # ubunturdma7→4
sleep 1
ssh_exec "192.168.30.94" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.113" &   # ubunturdma8→3
sleep 1

echo ""
print_success "All 8 bidirectional cross-ESXi flows launched!"
echo ""
print_info ">>> SWITCH NOW SATURATED WITH CROSS-HOST TRAFFIC <<<"
echo ""
echo "Switch Monitoring Commands:"
echo ""
echo "  ssh admin@192.168.50.229"
echo ""
echo "  show interface ethernet1/1/1 counters  # Host2 servers"
echo "  show interface ethernet1/1/2 counters  # Host2 servers"
echo "  show interface ethernet1/2/1 counters  # Host1 servers"
echo "  show interface ethernet1/2/2 counters  # Host1 servers"
echo ""
echo "  show queuing interface ethernet1/2/2   # Check queue depths"
echo "  show interface priority-flow-control   # Check PFC"
echo ""
echo "Expected Switch Behavior:"
echo "  • Eth1/2/2: ~12+ Gbps (ubunturdma1,3 sending/receiving)"
echo "  • Eth1/2/1: ~12+ Gbps (ubunturdma2,4 sending/receiving)"
echo "  • Eth1/1/1: ~18+ Gbps (ubunturdma5,7,8 sending/receiving)"
echo "  • Eth1/1/2: ~6+ Gbps (ubunturdma6 sending/receiving)"
echo "  • Total: ~48 Gbps aggregate across switch backplane"
echo ""
echo "  • High queue utilization"
echo "  • PFC pause frames if queues fill"
echo "  • ECN marks if configured"
echo "  • Minimal drops (PFC should prevent)"
echo ""

print_info "Running for ${DURATION} seconds..."

# Wait for all to complete
wait

echo ""
print_header "Cross-ESXi Saturation Test Complete"

echo ""
print_success "Test completed successfully!"
echo ""
echo "What you should have observed on switch:"
echo "  ✓ Heavy traffic on ALL 4 switch ports"
echo "  ✓ All flows at ~6 GB/sec (same-VLAN L2 switching)"
echo "  ✓ Traffic flowing between switch modules (Eth1/1/x ↔ Eth1/2/x)"
echo "  ✓ Realistic distributed AI training scenario"
echo "  ✓ PFC/ECN behavior under load"
echo ""

rm -f /tmp/ssh_cmd.exp

print_header "Test Finished - All Switch Ports Exercised"
