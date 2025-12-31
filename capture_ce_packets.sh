#!/bin/bash

# Capture CE-marked packets on servers 5, 7, 8 (highest np_ecn_marked_roce_packets)
OUTPUT_DIR="/mnt/c/Users/eniza/Documents/claudechats/ecn_pcaps"
mkdir -p "$OUTPUT_DIR"

echo "=== Capturing CE-Marked ECN Packets on Receiver Servers ==="
echo "Target servers: ubunturdma5, ubunturdma7, ubunturdma8"
echo "These servers have 92+ million CE-marked packets in NIC stats"
echo ""

# High-traffic receiver servers
declare -a servers=(
    "ubunturdma5:192.168.11.107:rocep11s0"
    "ubunturdma7:192.168.20.150:rocep11s0"
    "ubunturdma8:192.168.30.94:rocep11s0"
)

# Function to capture CE packets
capture_ce_packets() {
    local hostname=$1
    local ip=$2
    local device=$3
    local pcap_file="${hostname}_CE_capture.pcap"

    echo "=== Capturing on $hostname ($ip - $device) ==="
    echo "This server has received 92+ million CE-marked packets"

    expect << EXPECT_EOF
set timeout 120
spawn ssh -o StrictHostKeyChecking=no versa@${ip}
expect "password:"
send "<PASSWORD>\r"
expect "$ "

send "echo 'Capturing 500 packets on ${hostname}...'\\r"
expect "$ "

# Capture 500 packets (more chances to catch CE-marked packets)
send "echo '<PASSWORD>' | sudo -S docker run --rm -v /dev/infiniband:/dev/infiniband -v /tmp:/tmp --net=host --privileged mellanox/tcpdump-rdma tcpdump -i ${device} -c 500 -nn -w /tmp/${pcap_file} 'udp'\\r"
expect {
    "500 packets captured" {
        puts "\\nCapture complete for ${hostname}"
        expect "$ "
    }
    "packets captured" {
        puts "\\nPartial capture for ${hostname}"
        expect "$ "
    }
    timeout {
        puts "\\nCapture timeout for ${hostname}"
        expect "$ "
    }
}

send "ls -lh /tmp/${pcap_file} 2>&1\\r"
expect "$ "

send "exit\\r"
expect eof
EXPECT_EOF

    echo "Transferring ${pcap_file} via SCP..."

    expect << SCP_EOF
set timeout 45
spawn scp -o StrictHostKeyChecking=no versa@${ip}:/tmp/${pcap_file} ${OUTPUT_DIR}/
expect {
    "password:" {
        send "<PASSWORD>\r"
        expect eof
    }
    "No such file" {
        puts "File not found on remote server"
    }
    timeout {
        puts "SCP timeout"
    }
}
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

# Capture on all three high-traffic receivers
for server_info in "${servers[@]}"; do
    IFS=':' read -r hostname ip device <<< "$server_info"
    capture_ce_packets "$hostname" "$ip" "$device" > "$OUTPUT_DIR/${hostname}_CE.log" 2>&1 &
done

wait

echo ""
echo "=== CE Packet Captures Completed ==="
echo "Files saved in: $OUTPUT_DIR"
echo ""
ls -lh "$OUTPUT_DIR"/*CE_capture.pcap 2>/dev/null
echo ""
echo "To analyze and find CE-marked packets (tos 0x3):"
echo "  Open in Wireshark and filter: ip.dsfield.ecn == 3"
echo "  Or use: tcpdump -r <file>.pcap -nn -v 'udp' | grep 'tos 0x3'"
