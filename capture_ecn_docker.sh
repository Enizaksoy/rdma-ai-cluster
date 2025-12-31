#!/bin/bash

# ECN Bit Capture using Docker tcpdump-rdma on all 8 servers
OUTPUT_DIR="/mnt/c/Users/eniza/Documents/claudechats/ecn_captures"
mkdir -p "$OUTPUT_DIR"

echo "=== Capturing ECN Bits on All 8 Servers ==="
echo "Output directory: $OUTPUT_DIR"
echo ""

# Server configurations: name:ip:device
declare -a servers=(
    "ubunturdma1:192.168.11.152:rocep19s0"
    "ubunturdma2:192.168.11.153:rocep11s0"
    "ubunturdma3:192.168.11.154:rocep19s0"
    "ubunturdma4:192.168.11.155:rocep11s0"
    "ubunturdma5:192.168.11.107:rocep11s0"
    "ubunturdma6:192.168.12.51:rocep11s0"
    "ubunturdma7:192.168.20.150:rocep11s0"
    "ubunturdma8:192.168.30.94:rocep11s0"
)

# Function to capture on one server
capture_server() {
    local hostname=$1
    local ip=$2
    local device=$3

    echo "=== Capturing on $hostname ($ip - $device) ==="

    expect << EXPECT_EOF
set timeout 90
spawn ssh -o StrictHostKeyChecking=no versa@${ip}
expect "password:"
send "<PASSWORD>\r"
expect "$ "
send "echo 'Starting Docker capture on ${hostname}...'\r"
expect "$ "
send "echo '<PASSWORD>' | sudo -S docker run --rm -v /dev/infiniband:/dev/infiniband --net=host --privileged mellanox/tcpdump-rdma tcpdump -i ${device} -c 100 -nn -v 'udp' 2>&1 | grep 'tos 0x'\r"
expect {
    "tos 0x" {
        exp_continue
    }
    "100 packets captured" {
        puts "\nCapture complete for ${hostname}"
        expect "$ "
    }
    timeout {
        puts "\nCapture timeout for ${hostname}"
        expect "$ "
    }
}
send "exit\r"
expect eof
EXPECT_EOF

    echo ""
}

# Capture on all servers in parallel
for server_info in "${servers[@]}"; do
    IFS=':' read -r hostname ip device <<< "$server_info"
    capture_server "$hostname" "$ip" "$device" > "$OUTPUT_DIR/${hostname}_ecn.txt" 2>&1 &
done

wait

echo ""
echo "=== All captures completed ==="
echo "Results saved in: $OUTPUT_DIR"
echo ""
echo "Analysis:"
grep -h "tos 0x" "$OUTPUT_DIR"/*.txt | sort | uniq -c | sort -rn
