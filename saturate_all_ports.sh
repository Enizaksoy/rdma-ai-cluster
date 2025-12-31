#!/bin/bash

#############################################
# Maximum Switch Saturation - All 8 Servers
# Balanced flows across all switch ports
# Every port will show significant traffic
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

print_header "Maximum Switch Port Saturation - All 8 Servers"

echo ""
print_info "Switch Port Layout:"
echo "  Eth1/1/1: ubunturdma5, ubunturdma7, ubunturdma8"
echo "  Eth1/1/2: ubunturdma6"
echo "  Eth1/2/1: ubunturdma2, ubunturdma4"
echo "  Eth1/2/2: ubunturdma1, ubunturdma3"
echo ""

print_header "8 Bidirectional Cross-Port Flows"

echo ""
echo "Balanced flows to saturate ALL switch ports:"
echo ""
echo "  Group 1: Eth1/2/2 ↔ Eth1/2/1 (Cross-VLAN)"
echo "    1. ubunturdma1 (Eth1/2/2, Vlan251) → ubunturdma2 (Eth1/2/1, Vlan250)"
echo "    2. ubunturdma3 (Eth1/2/2, Vlan251) → ubunturdma4 (Eth1/2/1, Vlan250)"
echo ""
echo "  Group 2: Eth1/1/1 ↔ Eth1/1/2 (Same-VLAN)"
echo "    3. ubunturdma8 (Eth1/1/1, Vlan251) → ubunturdma6 (Eth1/1/2, Vlan251)"
echo "    4. ubunturdma5 (Eth1/1/1, Vlan250) → ubunturdma6 (Eth1/1/2, Vlan251) - Cross-VLAN"
echo ""
echo "  Group 3: Cross-Module Flows (Eth1/1/x ↔ Eth1/2/x)"
echo "    5. ubunturdma2 (Eth1/2/1, Vlan250) → ubunturdma7 (Eth1/1/1, Vlan250)"
echo "    6. ubunturdma4 (Eth1/2/1, Vlan250) → ubunturdma5 (Eth1/1/1, Vlan250)"
echo ""
echo "  Group 4: More Cross-Module Flows"
echo "    7. ubunturdma6 (Eth1/1/2, Vlan251) → ubunturdma1 (Eth1/2/2, Vlan251)"
echo "    8. ubunturdma7 (Eth1/1/1, Vlan250) → ubunturdma3 (Eth1/2/2, Vlan251) - Cross-VLAN"
echo ""
echo "Duration: ${DURATION} seconds"
echo ""

print_info ">>> GO TO YOUR SWITCH AND START MONITORING ALL 4 PORTS <<<"
echo ""

sleep 3

print_info "Starting RDMA servers on all 8 nodes..."

# Start servers (destinations)
expect /tmp/ssh_cmd.exp "192.168.11.153" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &  # ubunturdma2
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.155" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &  # ubunturdma4
sleep 1
expect /tmp/ssh_cmd.exp "192.168.12.51" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &   # ubunturdma6
sleep 1
expect /tmp/ssh_cmd.exp "192.168.20.150" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &  # ubunturdma7
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.107" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &  # ubunturdma5
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.152" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely" &  # ubunturdma1
sleep 1
expect /tmp/ssh_cmd.exp "192.168.11.154" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely" &  # ubunturdma3
sleep 1
expect /tmp/ssh_cmd.exp "192.168.30.94" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely" &   # ubunturdma8
sleep 1

sleep 5

print_success "All 8 servers ready as RDMA destinations"
echo ""
print_info "Starting RDMA clients (traffic generators)..."

# Group 1: Eth1/2/2 → Eth1/2/1 (Cross-VLAN, cross-port)
ssh_exec "192.168.11.152" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely 192.168.250.112" &  # ubunturdma1→2
sleep 1
ssh_exec "192.168.11.154" "ib_write_bw -d rocep19s0 -D $DURATION --run_infinitely 192.168.250.114" &  # ubunturdma3→4
sleep 1

# Group 2: Eth1/1/1 → Eth1/1/2 (cross-port)
ssh_exec "192.168.30.94" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.116" &   # ubunturdma8→6 (same VLAN)
sleep 1
ssh_exec "192.168.11.107" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.116" &  # ubunturdma5→6 (cross-VLAN)
sleep 1

# Group 3: Eth1/2/1 → Eth1/1/1 (cross-module, same VLAN)
ssh_exec "192.168.11.153" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.250.117" &  # ubunturdma2→7
sleep 1
ssh_exec "192.168.11.155" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.250.115" &  # ubunturdma4→5
sleep 1

# Group 4: Eth1/1/2 → Eth1/2/2 and Eth1/1/1 → Eth1/2/2 (cross-module)
ssh_exec "192.168.12.51" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.111" &   # ubunturdma6→1 (same VLAN)
sleep 1
ssh_exec "192.168.20.150" "ib_write_bw -d rocep11s0 -D $DURATION --run_infinitely 192.168.251.113" &  # ubunturdma7→3 (cross-VLAN)
sleep 1

echo ""
print_success "All 8 bidirectional flows launched!"
echo ""
print_info ">>> ALL SWITCH PORTS NOW SATURATED <<<"
echo ""
echo "Monitor on switch (192.168.50.229):"
echo ""
echo "  show interface ethernet1/1/1 counters"
echo "  show interface ethernet1/1/2 counters"
echo "  show interface ethernet1/2/1 counters"
echo "  show interface ethernet1/2/2 counters"
echo ""
echo "  show queuing interface ethernet1/1/1"
echo "  show queuing interface ethernet1/2/2"
echo ""
echo "  show interface priority-flow-control"
echo ""
echo "Expected behavior:"
echo "  • Eth1/1/1: Heavy traffic (3 servers sending/receiving)"
echo "  • Eth1/1/2: Heavy traffic (ubunturdma6 as hub)"
echo "  • Eth1/2/1: Moderate traffic (cross-VLAN + cross-module)"
echo "  • Eth1/2/2: Moderate traffic (cross-VLAN + cross-module)"
echo "  • Cross-VLAN flows: ~1 GB/sec (routing overhead)"
echo "  • Same-VLAN flows: ~6 GB/sec (L2 switching)"
echo "  • PFC pause frames on congested queues"
echo "  • ECN marks if configured"
echo ""

print_info "Running for ${DURATION} seconds..."

# Wait for all to complete
wait

echo ""
print_header "Switch Saturation Test Complete"

echo ""
print_success "All 8 servers completed testing!"
echo ""
echo "Next steps:"
echo "  1. Review switch port counters"
echo "  2. Check PFC statistics"
echo "  3. Analyze queue depths"
echo "  4. Look for ECN marks"
echo "  5. Compare cross-VLAN vs same-VLAN performance"
echo ""

rm -f /tmp/ssh_cmd.exp

print_header "Test Finished"
