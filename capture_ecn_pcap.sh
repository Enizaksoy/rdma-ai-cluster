#!/bin/bash

# ECN Bit Capture as PCAP files using Docker tcpdump-rdma on all 8 servers
OUTPUT_DIR="/mnt/c/Users/eniza/Documents/claudechats/ecn_pcaps"
mkdir -p "$OUTPUT_DIR"

echo "=== Capturing ECN Bits as PCAP on All 8 Servers ==="
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

# Function to capture on one server and retrieve pcap
capture_server_pcap() {
    local hostname=$1
    local ip=$2
    local device=$3
    local pcap_file="${hostname}_ecn.pcap"

    echo "=== Capturing on $hostname ($ip - $device) ==="

    expect << EXPECT_EOF
set timeout 90
spawn ssh -o StrictHostKeyChecking=no versa@${ip}
expect "password:"
send "<PASSWORD>\r"
expect "$ "

send "echo 'Starting PCAP capture on ${hostname}...'\\r"
expect "$ "

send "echo '<PASSWORD>' | sudo -S docker run --rm -v /dev/infiniband:/dev/infiniband -v /tmp:/tmp --net=host --privileged mellanox/tcpdump-rdma tcpdump -i ${device} -c 100 -nn -w /tmp/${pcap_file} 'udp'\\r"
expect {
    "100 packets captured" {
        puts "\\nCapture complete for ${hostname}"
        expect "$ "
    }
    timeout {
        puts "\\nCapture timeout for ${hostname}"
        expect "$ "
    }
}

send "ls -lh /tmp/${pcap_file}\\r"
expect "$ "

send "exit\\r"
expect eof
EXPECT_EOF

    echo "Transferring ${pcap_file} via SCP..."

    expect << SCP_EOF
set timeout 30
spawn scp -o StrictHostKeyChecking=no versa@${ip}:/tmp/${pcap_file} ${OUTPUT_DIR}/
expect "password:"
send "<PASSWORD>\r"
expect eof
SCP_EOF

    # Clean up remote file
    expect << CLEANUP_EOF
set timeout 10
spawn ssh -o StrictHostKeyChecking=no versa@${ip}
expect "password:"
send "<PASSWORD>\r"
expect "$ "
send "rm -f /tmp/${pcap_file}\\r"
expect "$ "
send "exit\\r"
expect eof
CLEANUP_EOF

    echo "Completed: $hostname"
    echo ""
}

# Capture on all servers in parallel
for server_info in "${servers[@]}"; do
    IFS=':' read -r hostname ip device <<< "$server_info"
    capture_server_pcap "$hostname" "$ip" "$device" > "$OUTPUT_DIR/${hostname}_capture.log" 2>&1 &
done

wait

echo ""
echo "=== All PCAP captures completed ==="
echo "PCAP files saved in: $OUTPUT_DIR"
echo ""
echo "Files:"
ls -lh "$OUTPUT_DIR"/*.pcap 2>/dev/null

echo ""
echo "To analyze PCAP files with tcpdump:"
echo "  tcpdump -r $OUTPUT_DIR/ubunturdma1_ecn.pcap -nn -v 'udp' | grep 'tos 0x'"
echo ""
echo "To analyze with Wireshark (if available):"
echo "  wireshark $OUTPUT_DIR/ubunturdma1_ecn.pcap"
