#!/bin/bash

# 5-second capture on servers 5, 7, 8
OUTPUT_DIR="/mnt/c/Users/eniza/Documents/claudechats/ecn_pcaps"
mkdir -p "$OUTPUT_DIR"

echo "=== 5-Second ECN Capture on Servers 5, 7, 8 ==="
echo ""

declare -a servers=(
    "ubunturdma5:192.168.11.107:rocep11s0"
    "ubunturdma7:192.168.20.150:rocep11s0"
    "ubunturdma8:192.168.30.94:rocep11s0"
)

capture_5sec() {
    local hostname=$1
    local ip=$2
    local device=$3
    local pcap_file="${hostname}_5sec.pcap"

    echo "=== Capturing 5 seconds on $hostname ($ip) ==="

    expect << EXPECT_EOF
set timeout 20
spawn ssh -o StrictHostKeyChecking=no versa@${ip}
expect "password:"
send "Versa@123!!\r"
expect "$ "

send "echo 'Versa@123!!' | sudo -S timeout 5 docker run --rm -v /dev/infiniband:/dev/infiniband -v /tmp:/tmp --net=host --privileged mellanox/tcpdump-rdma tcpdump -i ${device} -nn -w /tmp/${pcap_file} 'udp'\\r"
expect {
    "packets captured" {
        expect "$ "
    }
    "$ " {}
    timeout {
        expect "$ "
    }
}

send "ls -lh /tmp/${pcap_file} 2>&1\\r"
expect "$ "

send "exit\\r"
expect eof
EXPECT_EOF

    echo "Transferring ${pcap_file}..."
    sshpass -p 'Versa@123!!' scp -o StrictHostKeyChecking=no versa@${ip}:/tmp/${pcap_file} ${OUTPUT_DIR}/ 2>&1
    sshpass -p 'Versa@123!!' ssh -o StrictHostKeyChecking=no versa@${ip} "rm -f /tmp/${pcap_file}" 2>&1

    echo "Done: $hostname"
    echo ""
}

# Capture all in parallel
for server_info in "${servers[@]}"; do
    IFS=':' read -r hostname ip device <<< "$server_info"
    capture_5sec "$hostname" "$ip" "$device" &
done

wait

echo ""
echo "=== 5-Second Capture Complete ==="
ls -lh "$OUTPUT_DIR"/*5sec.pcap 2>/dev/null
