#!/bin/bash

echo "=== NIC Tuning for AI Training (v2) - All 8 Servers ==="
echo ""

declare -a servers=(
    "ubunturdma1:192.168.11.152"
    "ubunturdma2:192.168.11.153"
    "ubunturdma3:192.168.11.154"
    "ubunturdma4:192.168.11.155"
    "ubunturdma5:192.168.11.107"
    "ubunturdma6:192.168.12.51"
    "ubunturdma7:192.168.20.150"
    "ubunturdma8:192.168.30.94"
)

tune_server() {
    local hostname=$1
    local ip=$2

    echo "=== Tuning $hostname ($ip) ==="

    expect << 'EXPECT_EOF'
set hostname [lindex $argv 0]
set ip [lindex $argv 1]
set timeout 30

spawn ssh -o StrictHostKeyChecking=no versa@$ip
expect "password:"
send "<PASSWORD>\r"
expect "$ "

# Check current settings
send "echo '=== Current RDMA Stats ==='\r"
expect "$ "
send "rdma statistic show 2>/dev/null | head -5\r"
expect "$ "

# Enable TCP ECN
send "echo '<PASSWORD>' | sudo -S sysctl -w net.ipv4.tcp_ecn=1\r"
expect "$ "

# Find MST device
send "ls /dev/mst/ 2>/dev/null\r"
expect "$ "

# Query current mlxconfig settings
send "echo '<PASSWORD>' | sudo -S mst start 2>&1\r"
expect "$ "
send "echo '<PASSWORD>' | sudo -S mlxconfig -d /dev/mst/mt*_pciconf0 q 2>&1 | grep -E 'ROCE_CC|PFC|LOSSLESS' | head -10\r"
expect "$ "

send "echo '✅ Tuning complete for $hostname'\r"
expect "$ "

send "exit\r"
expect eof
EXPECT_EOF $hostname $ip

    echo ""
}

# Tune all servers
for server_info in "${servers[@]}"; do
    IFS=':' read -r hostname ip <<< "$server_info"
    tune_server "$hostname" "$ip"
done

echo ""
echo "=== Tuning Summary ==="
echo "Checked all 8 servers for current ECN/PFC/DCQCN settings"
