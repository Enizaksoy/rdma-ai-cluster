#!/bin/bash

#############################################
# RDMA Cluster Full Test Suite
# Tests all 8 servers for RDMA connectivity
# and performance
#############################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Server definitions
declare -A SERVERS_MGMT=(
    ["ubunturdma1"]="192.168.11.152"
    ["ubunturdma2"]="192.168.11.153"
    ["ubunturdma3"]="192.168.11.154"
    ["ubunturdma4"]="192.168.11.155"
    ["ubunturdma5"]="192.168.11.107"
    ["ubunturdma6"]="192.168.12.51"
    ["ubunturdma7"]="192.168.20.150"
    ["ubunturdma8"]="192.168.30.94"
)

declare -A SERVERS_RDMA=(
    ["ubunturdma1"]="192.168.251.111"
    ["ubunturdma2"]="192.168.250.112"
    ["ubunturdma3"]="192.168.251.113"
    ["ubunturdma4"]="192.168.250.114"
    ["ubunturdma5"]="192.168.250.115"
    ["ubunturdma6"]="192.168.251.116"
    ["ubunturdma7"]="192.168.250.117"
    ["ubunturdma8"]="192.168.251.118"
)

# VLAN assignments
VLAN251_SERVERS=("ubunturdma1" "ubunturdma3" "ubunturdma6" "ubunturdma8")
VLAN250_SERVERS=("ubunturdma2" "ubunturdma4" "ubunturdma5" "ubunturdma7")

PASSWORD="<PASSWORD>"
OUTPUT_FILE="/mnt/c/Users/eniza/Documents/claudechats/rdma_test_results_$(date +%Y%m%d_%H%M%S).txt"

# Create expect script helper
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

# Execute SSH command using expect
ssh_exec() {
    local ip=$1
    local cmd=$2
    expect /tmp/ssh_cmd.exp "$ip" "$cmd" 2>/dev/null
}

# Print header
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Print subheader
print_subheader() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"
}

# Start logging
exec > >(tee -a "$OUTPUT_FILE")
exec 2>&1

echo "RDMA Cluster Test Suite"
echo "Started: $(date)"
echo "Output file: $OUTPUT_FILE"
echo ""

# Create expect script
create_expect_script

#############################################
# TEST 1: Network Interface Discovery
#############################################
print_header "TEST 1: Network Interface Discovery"

for server in "${!SERVERS_MGMT[@]}"; do
    mgmt_ip=${SERVERS_MGMT[$server]}
    print_subheader "$server ($mgmt_ip)"

    ssh_exec "$mgmt_ip" "hostname && echo 'Management:' && ip addr show | grep -E 'inet 192.168' | awk '{print \$NF, \$2}'"
    echo ""
done

#############################################
# TEST 2: RDMA Hardware Detection
#############################################
print_header "TEST 2: RDMA Hardware Detection"

for server in "${!SERVERS_MGMT[@]}"; do
    mgmt_ip=${SERVERS_MGMT[$server]}
    print_subheader "$server - RDMA Devices"

    ssh_exec "$mgmt_ip" "ibv_devices"
    echo ""
done

#############################################
# TEST 3: RDMA Modules and Drivers
#############################################
print_header "TEST 3: RDMA Kernel Modules"

for server in "${!SERVERS_MGMT[@]}"; do
    mgmt_ip=${SERVERS_MGMT[$server]}
    print_subheader "$server - Loaded RDMA Modules"

    ssh_exec "$mgmt_ip" "lsmod | grep -iE 'rdma|ib_|mlx' | head -10 || echo 'No RDMA modules found'"
    echo ""
done

#############################################
# TEST 4: Ping Tests - Vlan251
#############################################
print_header "TEST 4: Network Connectivity - Vlan251"

source_server="ubunturdma1"
source_mgmt=${SERVERS_MGMT[$source_server]}

print_subheader "Pinging from $source_server to other Vlan251 servers"

for target_server in "${VLAN251_SERVERS[@]}"; do
    if [ "$target_server" != "$source_server" ]; then
        target_rdma=${SERVERS_RDMA[$target_server]}
        echo -n "  $source_server -> $target_server ($target_rdma): "

        result=$(ssh_exec "$source_mgmt" "ping -c 2 -W 2 $target_rdma 2>&1 | grep -E 'packets transmitted|100% packet loss'")

        if echo "$result" | grep -q "0% packet loss"; then
            echo -e "${GREEN}✓ SUCCESS${NC}"
        else
            echo -e "${RED}✗ FAILED${NC}"
        fi
        echo "$result" | grep "packets transmitted"
        echo ""
    fi
done

#############################################
# TEST 5: Ping Tests - Vlan250
#############################################
print_header "TEST 5: Network Connectivity - Vlan250"

source_server="ubunturdma2"
source_mgmt=${SERVERS_MGMT[$source_server]}

print_subheader "Pinging from $source_server to other Vlan250 servers"

for target_server in "${VLAN250_SERVERS[@]}"; do
    if [ "$target_server" != "$source_server" ]; then
        target_rdma=${SERVERS_RDMA[$target_server]}
        echo -n "  $source_server -> $target_server ($target_rdma): "

        result=$(ssh_exec "$source_mgmt" "ping -c 2 -W 2 $target_rdma 2>&1 | grep -E 'packets transmitted|100% packet loss'")

        if echo "$result" | grep -q "0% packet loss"; then
            echo -e "${GREEN}✓ SUCCESS${NC}"
        else
            echo -e "${RED}✗ FAILED${NC}"
        fi
        echo "$result" | grep "packets transmitted"
        echo ""
    fi
done

#############################################
# TEST 6: Cross-VLAN Connectivity
#############################################
print_header "TEST 6: Cross-VLAN Connectivity Test"

source_server="ubunturdma1"
source_mgmt=${SERVERS_MGMT[$source_server]}
target_server="ubunturdma2"
target_rdma=${SERVERS_RDMA[$target_server]}

print_subheader "$source_server (Vlan251) -> $target_server (Vlan250)"

result=$(ssh_exec "$source_mgmt" "ping -c 3 -W 2 $target_rdma 2>&1 | grep 'packets transmitted'")
echo "$result"
echo ""

#############################################
# TEST 7: RDMA Bandwidth Test - Vlan251
#############################################
print_header "TEST 7: RDMA Bandwidth Test - Vlan251"

server1="ubunturdma1"
server2="ubunturdma3"
server1_mgmt=${SERVERS_MGMT[$server1]}
server2_mgmt=${SERVERS_MGMT[$server2]}
server2_rdma=${SERVERS_RDMA[$server2]}

print_subheader "$server1 <-> $server2 RDMA Performance"

# Determine RDMA device names
device1=$(ssh_exec "$server1_mgmt" "ibv_devices | grep roce | awk '{print \$1}'" | tr -d '\r')
device2=$(ssh_exec "$server2_mgmt" "ibv_devices | grep roce | awk '{print \$1}'" | tr -d '\r')

echo "Starting RDMA server on $server2 (device: $device2)..."

# Start server in background
expect /tmp/ssh_cmd.exp "$server2_mgmt" "timeout 20 ib_write_bw -d $device2" &
server_pid=$!

# Wait for server to start
sleep 4

echo "Running RDMA client from $server1 (device: $device1)..."

# Run client
client_output=$(ssh_exec "$server1_mgmt" "ib_write_bw -d $device1 $server2_rdma" 2>&1)

echo "$client_output" | grep -A 20 "RDMA_Write BW Test"
echo ""
echo "Bandwidth Result:"
echo "$client_output" | grep "65536" | tail -1

# Cleanup
wait $server_pid 2>/dev/null

echo ""

#############################################
# TEST 8: RDMA Bandwidth Test - Vlan250
#############################################
print_header "TEST 8: RDMA Bandwidth Test - Vlan250"

server1="ubunturdma4"
server2="ubunturdma2"
server1_mgmt=${SERVERS_MGMT[$server1]}
server2_mgmt=${SERVERS_MGMT[$server2]}
server2_rdma=${SERVERS_RDMA[$server2]}

print_subheader "$server1 <-> $server2 RDMA Performance"

# Determine RDMA device names
device1=$(ssh_exec "$server1_mgmt" "ibv_devices | grep roce | awk '{print \$1}'" | tr -d '\r')
device2=$(ssh_exec "$server2_mgmt" "ibv_devices | grep roce | awk '{print \$1}'" | tr -d '\r')

echo "Starting RDMA server on $server2 (device: $device2)..."

# Start server in background
expect /tmp/ssh_cmd.exp "$server2_mgmt" "timeout 20 ib_write_bw -d $device2" &
server_pid=$!

# Wait for server to start
sleep 4

echo "Running RDMA client from $server1 (device: $device1)..."

# Run client
client_output=$(ssh_exec "$server1_mgmt" "ib_write_bw -d $device1 $server2_rdma" 2>&1)

echo "$client_output" | grep -A 20 "RDMA_Write BW Test"
echo ""
echo "Bandwidth Result:"
echo "$client_output" | grep "65536" | tail -1

# Cleanup
wait $server_pid 2>/dev/null

echo ""

#############################################
# TEST 9: RDMA Device Information
#############################################
print_header "TEST 9: Detailed RDMA Device Information"

for server in "${!SERVERS_MGMT[@]}"; do
    mgmt_ip=${SERVERS_MGMT[$server]}
    print_subheader "$server - Device Details"

    ssh_exec "$mgmt_ip" "ibv_devinfo | head -30"
    echo ""
done

#############################################
# Summary
#############################################
print_header "TEST SUMMARY"

echo -e "${GREEN}All tests completed!${NC}"
echo ""
echo "Results saved to: $OUTPUT_FILE"
echo "Completed: $(date)"
echo ""
echo "Next steps:"
echo "  1. Review the test results above"
echo "  2. If all tests passed, cluster is ready for AI/ML workloads"
echo "  3. Proceed with PyTorch + NCCL installation"
echo ""

# Cleanup
rm -f /tmp/ssh_cmd.exp

echo -e "${BLUE}========================================${NC}"
