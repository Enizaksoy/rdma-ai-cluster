#!/bin/bash

echo "=== Checking CNP Handling on Sender Servers ==="
echo "Looking for rp_cnp_handled (CNP packets received and acted upon)"
echo ""

# Check servers that showed ECN stats (5, 6, 7, 8)
declare -a servers=(
    "ubunturdma5:192.168.11.107:rocep11s0"
    "ubunturdma6:192.168.12.51:rocep11s0"
    "ubunturdma7:192.168.20.150:rocep11s0"
    "ubunturdma8:192.168.30.94:rocep11s0"
)

for server_info in "${servers[@]}"; do
    IFS=':' read -r hostname ip device <<< "$server_info"

    echo "=== $hostname ($ip) ==="

    sshpass -p '<PASSWORD>' ssh -o StrictHostKeyChecking=no versa@${ip} \
        "rdma statistic show link ${device}/1 2>/dev/null | grep -E 'rp_cnp_handled|rp_cnp_ignored'" 2>&1 | grep -E "rp_cnp|$hostname"

    echo ""
done

echo "=== Summary ==="
echo "rp_cnp_handled: Number of CNP packets received and processed by sender"
echo "rp_cnp_ignored: CNP packets ignored"
echo ""
echo "High rp_cnp_handled = Sender is receiving CNPs and reducing rate ✅"
