#!/bin/bash

#############################################
# Monitored RDMA Test with Switch Statistics
# Runs RDMA tests + monitors Cisco Nexus switch
#############################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SWITCH_IP="192.168.50.229"
SWITCH_USER="admin"
SWITCH_PASS="<PASSWORD>"
DURATION=${1:-60}  # Default 60 seconds
SAMPLE_INTERVAL=5   # Sample every 5 seconds

# Switch ports to monitor
PORTS=("ethernet1/1/1" "ethernet1/1/2" "ethernet1/2/1" "ethernet1/2/2")

OUTPUT_DIR="/mnt/c/Users/eniza/Documents/claudechats"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RDMA_LOG="${OUTPUT_DIR}/rdma_test_${TIMESTAMP}.log"
SWITCH_LOG="${OUTPUT_DIR}/switch_stats_${TIMESTAMP}.log"
SUMMARY_LOG="${OUTPUT_DIR}/test_summary_${TIMESTAMP}.txt"

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

print_cyan() {
    echo -e "${CYAN}$1${NC}"
}

# Create expect script for switch access
create_switch_expect() {
    cat > /tmp/switch_monitor.exp << 'EOFEXP'
#!/usr/bin/expect -f
set ip [lindex $argv 0]
set cmd [lindex $argv 1]
set timeout 10
spawn ssh -o StrictHostKeyChecking=no admin@$ip
expect "Password:"
send "<PASSWORD>\r"
expect "#"
send "$cmd\r"
expect "#"
send "exit\r"
expect eof
EOFEXP
    chmod +x /tmp/switch_monitor.exp
}

# Function to get switch statistics
get_switch_stats() {
    local port=$1
    local timestamp=$2

    echo "=== Port $port - Time: $timestamp ===" >> "$SWITCH_LOG"

    # Get interface counters
    expect /tmp/switch_monitor.exp "$SWITCH_IP" "show interface $port counters" >> "$SWITCH_LOG" 2>&1

    # Get queue statistics
    expect /tmp/switch_monitor.exp "$SWITCH_IP" "show queuing interface $port" >> "$SWITCH_LOG" 2>&1

    # Get PFC statistics
    expect /tmp/switch_monitor.exp "$SWITCH_IP" "show interface $port priority-flow-control" >> "$SWITCH_LOG" 2>&1

    echo "" >> "$SWITCH_LOG"
}

# Function to run RDMA bandwidth test
run_rdma_test() {
    print_info "Starting RDMA bandwidth tests..."

    # Create server access script
    cat > /tmp/ssh_server.exp << 'EOFEXP2'
#!/usr/bin/expect -f
set ip [lindex $argv 0]
set cmd [lindex $argv 1]
set timeout 120
spawn ssh -o StrictHostKeyChecking=no versa@$ip "$cmd"
expect {
    "password:" {
        send "<PASSWORD>\r"
        exp_continue
    }
    eof
}
EOFEXP2
    chmod +x /tmp/ssh_server.exp

    # Test 1: Vlan251 - ubunturdma1 to ubunturdma3
    print_info "Test 1: ubunturdma1 → ubunturdma3 (Vlan251)"

    expect /tmp/ssh_server.exp "192.168.11.154" "ib_write_bw -d rocep19s0 -D $DURATION" > /tmp/server1.log 2>&1 &
    sleep 3
    expect /tmp/ssh_server.exp "192.168.11.152" "ib_write_bw -d rocep19s0 -D $DURATION 192.168.251.113" > "$RDMA_LOG" 2>&1 &

    # Test 2: Vlan250 - ubunturdma4 to ubunturdma2
    sleep 5
    print_info "Test 2: ubunturdma4 → ubunturdma2 (Vlan250)"

    expect /tmp/ssh_server.exp "192.168.11.153" "ib_write_bw -d rocep11s0 -D $DURATION" > /tmp/server2.log 2>&1 &
    sleep 3
    expect /tmp/ssh_server.exp "192.168.11.155" "ib_write_bw -d rocep11s0 -D $DURATION 192.168.250.112" >> "$RDMA_LOG" 2>&1 &
}

# Monitor switch in background
monitor_switch() {
    local end_time=$(($(date +%s) + DURATION + 10))
    local sample=0

    print_info "Starting switch monitoring..."

    while [ $(date +%s) -lt $end_time ]; do
        ((sample++))
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        echo "" >> "$SWITCH_LOG"
        echo "########## SAMPLE #$sample - $timestamp ##########" >> "$SWITCH_LOG"

        for port in "${PORTS[@]}"; do
            get_switch_stats "$port" "$timestamp"
        done

        print_cyan "  Sample #$sample collected at $timestamp"

        sleep $SAMPLE_INTERVAL
    done

    print_success "Switch monitoring completed - $sample samples collected"
}

# Generate summary report
generate_summary() {
    print_info "Generating summary report..."

    exec > >(tee "$SUMMARY_LOG")

    print_header "RDMA Test with Switch Monitoring - Summary Report"

    echo ""
    echo "Test Date: $(date)"
    echo "Duration: ${DURATION} seconds"
    echo "Sample Interval: ${SAMPLE_INTERVAL} seconds"
    echo ""

    print_header "Switch Port Mapping"
    echo ""
    echo "Eth1/1/1: ubunturdma5, ubunturdma7, ubunturdma8"
    echo "Eth1/1/2: ubunturdma6"
    echo "Eth1/2/1: ubunturdma2, ubunturdma4"
    echo "Eth1/2/2: ubunturdma1, ubunturdma3"
    echo ""

    print_header "RDMA Bandwidth Results"
    echo ""

    if [ -f "$RDMA_LOG" ]; then
        echo "Test 1 - Vlan251 (ubunturdma1 → ubunturdma3):"
        grep "65536" "$RDMA_LOG" | head -1
        echo ""
        echo "Test 2 - Vlan250 (ubunturdma4 → ubunturdma2):"
        grep "65536" "$RDMA_LOG" | tail -1
    else
        echo "RDMA test log not found"
    fi

    echo ""
    print_header "Switch Statistics Analysis"
    echo ""

    if [ -f "$SWITCH_LOG" ]; then
        # Count PFC pause frames
        echo "PFC Pause Frame Analysis:"
        for port in "${PORTS[@]}"; do
            port_short=$(echo $port | sed 's/ethernet/Eth/')
            pfc_tx=$(grep -A 20 "$port_short" "$SWITCH_LOG" | grep "TxPPP:" | tail -1 | awk '{print $2}')
            pfc_rx=$(grep -A 20 "$port_short" "$SWITCH_LOG" | grep "RxPPP:" | tail -1 | awk '{print $4}')
            echo "  $port_short: TX=$pfc_tx, RX=$pfc_rx pause frames"
        done

        echo ""
        echo "Packet Drop Analysis:"
        for port in "${PORTS[@]}"; do
            port_short=$(echo $port | sed 's/ethernet/Eth/')
            drops=$(grep "Drop" "$SWITCH_LOG" | grep -A 5 "$port_short" | tail -1)
            echo "  $port_short: Check switch log for details"
        done

        echo ""
        echo "Queue Depth Analysis:"
        echo "  See switch log for detailed queue statistics"
    else
        echo "Switch statistics log not found"
    fi

    echo ""
    print_header "Files Generated"
    echo ""
    echo "1. RDMA Test Results: $RDMA_LOG"
    echo "2. Switch Statistics: $SWITCH_LOG"
    echo "3. Summary Report: $SUMMARY_LOG"
    echo ""

    print_header "Quick Analysis Commands"
    echo ""
    echo "# View RDMA bandwidth:"
    echo "grep '65536' $RDMA_LOG"
    echo ""
    echo "# Check PFC pause frames:"
    echo "grep 'TxPPP\\|RxPPP' $SWITCH_LOG"
    echo ""
    echo "# Check packet drops:"
    echo "grep -i 'drop' $SWITCH_LOG | grep -v '0 pkts'"
    echo ""
    echo "# View queue depths:"
    echo "grep 'Q Depth' $SWITCH_LOG"
    echo ""

    exec > /dev/tty
}

#############################################
# Main execution
#############################################

print_header "Monitored RDMA Test - Starting"

echo ""
print_info "Configuration:"
echo "  Switch: $SWITCH_IP (Cisco Nexus - NX_AI_Leaf1)"
echo "  Test Duration: ${DURATION} seconds"
echo "  Monitoring Interval: ${SAMPLE_INTERVAL} seconds"
echo "  Ports Monitored: ${#PORTS[@]} ports"
echo ""

# Create expect script
create_switch_expect

# Get baseline statistics
print_info "Collecting baseline statistics..."
for port in "${PORTS[@]}"; do
    get_switch_stats "$port" "BASELINE"
done

echo ""
print_success "Baseline collected"
echo ""

# Start switch monitoring in background
monitor_switch &
MONITOR_PID=$!

sleep 2

# Start RDMA tests
run_rdma_test

# Wait for completion
print_info "Tests running... (${DURATION} seconds)"
print_info "Monitoring switch every ${SAMPLE_INTERVAL} seconds"
echo ""

wait

# Generate summary
generate_summary

print_header "Test Complete!"

echo ""
print_success "All tests and monitoring completed successfully!"
echo ""
echo "Review the files:"
echo "  1. Summary: $SUMMARY_LOG"
echo "  2. RDMA Results: $RDMA_LOG"
echo "  3. Switch Stats: $SWITCH_LOG"
echo ""

# Cleanup
rm -f /tmp/switch_monitor.exp /tmp/ssh_server.exp /tmp/server*.log

print_header "Script Complete"
