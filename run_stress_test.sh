#!/bin/bash

#############################################
# Combined Network Stress Test
# Runs intensive training + network monitoring
#############################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DURATION=${1:-300}

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

print_header "Network Stress Test - Training + Monitoring"

echo ""
print_info "Configuration:"
echo "  Duration: $DURATION seconds ($(($DURATION / 60)) minutes)"
echo "  Training: 8-node distributed training"
echo "  Monitoring: RDMA/PFC/ECN statistics"
echo ""
echo "This will:"
echo "  1. Start intensive AI training on all 8 nodes"
echo "  2. Monitor network statistics every 10 seconds"
echo "  3. Generate reports for analysis"
echo ""

read -p "Press Enter to start..."

echo ""
print_info "Starting network monitoring in background..."

# Start monitoring
/mnt/c/Users/eniza/Documents/claudechats/monitor_network.sh $DURATION &
MONITOR_PID=$!

sleep 2

print_info "Starting intensive training..."

# Start training
/mnt/c/Users/eniza/Documents/claudechats/intensive_training.sh $DURATION

# Wait for monitoring to complete
wait $MONITOR_PID

echo ""
print_header "Stress Test Complete"

echo ""
print_success "Both training and monitoring completed!"
echo ""
echo "Check the following files:"
echo "  - network_monitor_*.log - Network statistics"
echo "  - Look for PFC frames, ECN marks, queue depths"
echo ""
echo "Next steps:"
echo "  1. Analyze network statistics"
echo "  2. Check switch for PFC/ECN activity"
echo "  3. Review queue utilization"
echo ""

echo -e "${BLUE}========================================${NC}"
