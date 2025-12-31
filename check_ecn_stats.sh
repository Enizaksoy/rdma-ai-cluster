#!/bin/bash

echo "=== Checking ECN Statistics on All Servers ==="
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

for server_info in "${servers[@]}"; do
    IFS=':' read -r hostname ip device <<< "$server_info"

    echo "=== $hostname ($ip - $device) ==="

    expect << EXPECT_EOF
set timeout 15
spawn ssh -o StrictHostKeyChecking=no versa@${ip}
expect "password:"
send "<PASSWORD>\r"
expect "$ "

send "rdma statistic show link ${device}/1 2>/dev/null | grep -Ei 'np_ecn_marked_roce_packets|np_cnp_sent|rp_cnp_handled' || echo 'No ECN stats available'\r"
expect "$ "

send "exit\r"
expect eof
EXPECT_EOF

    echo ""
done

echo "=== Summary ==="
echo "Look for servers with high np_ecn_marked_roce_packets (these are receiving CE-marked packets)"
