#!/bin/bash

echo "=============================================="
echo "  AI Training Traffic Monitor"
echo "  Real-time ECN/PFC/RDMA Statistics"
echo "=============================================="
echo ""
echo "This will monitor:"
echo "  1. Switch queue statistics (drops, ECN)"
echo "  2. PFC pause frames"
echo "  3. Server RDMA CNP activity"
echo ""
echo "Open 3 terminal windows and run each monitor:"
echo ""

cat << 'MONITOR_SCRIPT'
# ========================================
# TERMINAL 1: Switch Queue Monitor
# ========================================
echo "Monitor 1: Switch Ingress/Egress Queues"
echo "Run this on your local machine:"
echo ""
echo "watch -n 1 'sshpass -p \"<PASSWORD>\" ssh admin@192.168.50.229 \"show queuing interface ethernet1/1/1\" | grep -E \"Ingress MMU Drop|WRED Drop|Tx Pkts\"'"
echo ""
echo "What to watch:"
echo "  - Ingress MMU Drop Pkts: Should stay low (currently 2M)"
echo "  - WRED Drop Pkts: Should stay 0 (ECN marking instead)"
echo "  - Tx Pkts: Should increase rapidly during training"
echo ""
echo "---"
echo ""

# ========================================
# TERMINAL 2: Switch PFC Monitor
# ========================================
echo "Monitor 2: PFC Pause Frames"
echo "Run this on your local machine:"
echo ""
echo "watch -n 1 'sshpass -p \"<PASSWORD>\" ssh admin@192.168.50.229 \"show interface priority-flow-control | grep -E \\\"Ethernet1/1|ii1/1\\\"\"'"
echo ""
echo "What to watch:"
echo "  - RxPPP/TxPPP counters on Ethernet1/1/x (edge ports)"
echo "  - RxPPP/TxPPP counters on ii1/1/x (fabric ports - should be high)"
echo ""
echo "---"
echo ""

# ========================================
# TERMINAL 3: Server RDMA/CNP Monitor
# ========================================
echo "Monitor 3: Server RDMA CNP Activity"
echo "Run this on your local machine:"
echo ""
echo "watch -n 1 'sshpass -p \"<PASSWORD>\" ssh versa@192.168.11.107 \"rdma statistic show link rocep11s0/1 | grep -E \\\"cnp|ecn\\\"\"'"
echo ""
echo "What to watch:"
echo "  - rp_cnp_handled: Should increase (receiving CNPs)"
echo "  - np_ecn_marked_roce_packets: Should increase (receiving CE packets)"
echo "  - np_cnp_sent: Should increase (sending CNPs)"
echo ""
echo "---"
echo ""

# ========================================
# BONUS: Packet Capture During Training
# ========================================
echo "BONUS: Capture ECN Packets During Training"
echo ""
echo "On ubunturdma7 (while training is running):"
echo ""
echo "ssh versa@192.168.20.150"
echo "sudo timeout 10 docker run --rm -v /dev/infiniband:/dev/infiniband --net=host --privileged mellanox/tcpdump-rdma tcpdump -i rocep11s0 -c 100 -nn -v 'udp' | grep 'tos 0x'"
echo ""
echo "Expected to see:"
echo "  - tos 0x2 (ECT - ECN capable packets)"
echo "  - tos 0x3 (CE - Congestion Experienced, marked by switch!)"
echo ""

MONITOR_SCRIPT
