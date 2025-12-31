#!/bin/bash

# Capture ECN bits on all 8 Ubuntu RDMA servers
OUTPUT_DIR="/mnt/c/Users/eniza/Documents/claudechats/rdma_captures"
mkdir -p "$OUTPUT_DIR"

echo "=== RDMA ECN Capture on All Servers ==="
echo "Output directory: $OUTPUT_DIR"
echo ""

# Server configurations
declare -A servers=(
    ["ubunturdma1"]="192.168.11.152:rocep19s0"
    ["ubunturdma2"]="192.168.11.153:rocep11s0"
    ["ubunturdma3"]="192.168.11.154:rocep19s0"
    ["ubunturdma4"]="192.168.11.155:rocep11s0"
    ["ubunturdma5"]="192.168.11.156:rocep11s0"
    ["ubunturdma6"]="192.168.11.157:rocep11s0"
    ["ubunturdma7"]="192.168.11.158:rocep11s0"
    ["ubunturdma8"]="192.168.11.159:rocep11s0"
)

# Function to capture on one server
capture_server() {
    local hostname=$1
    local ip=$2
    local device=$3
    local output_file="$OUTPUT_DIR/${hostname}_ecn_capture.txt"
    
    echo "=== Capturing on $hostname ($ip - $device) ==="
    
    expect << EXPECT_EOF
set timeout 60
spawn ssh -o StrictHostKeyChecking=no versa@${ip}
expect "password:"
send "<PASSWORD>\r"
expect "$ "
send "echo 'Starting capture on ${hostname}...'\r"
expect "$ "
send "echo '<PASSWORD>' | sudo -S docker run --rm -v /dev/infiniband:/dev/infiniband --net=host --privileged mellanox/tcpdump-rdma tcpdump -i ${device} -c 100 -nn -v 'udp port 4791' 2>&1 | grep 'tos 0x' | head -50\r"
expect {
    "tos 0x" {
        exp_continue
    }
    "packets captured" {
        expect "$ "
    }
    timeout {
        puts "\nTimeout on ${hostname}"
    }
}
send "exit\r"
expect eof
EXPECT_EOF

    echo "Capture completed for $hostname"
    echo ""
}

# Capture on all servers
for hostname in "${!servers[@]}"; do
    IFS=':' read -r ip device <<< "${servers[$hostname]}"
    capture_server "$hostname" "$ip" "$device" > "$OUTPUT_DIR/${hostname}_ecn_capture.txt" 2>&1 &
done

wait
echo "=== All captures completed ==="
echo "Results saved in: $OUTPUT_DIR"
