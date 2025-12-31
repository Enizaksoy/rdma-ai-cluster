#!/bin/bash

echo "=== NIC Tuning for AI Training - All 8 Servers ==="
echo "Objective: Reduce microburst traffic to prevent ingress drops"
echo ""

# All 8 servers
declare -a servers=(
    "ubunturdma1:192.168.11.152:rocep19s0:mlx5_2"
    "ubunturdma2:192.168.11.153:rocep11s0:mlx5_0"
    "ubunturdma3:192.168.11.154:rocep19s0:mlx5_2"
    "ubunturdma4:192.168.11.155:rocep11s0:mlx5_0"
    "ubunturdma5:192.168.11.107:rocep11s0:mlx5_0"
    "ubunturdma6:192.168.12.51:rocep11s0:mlx5_0"
    "ubunturdma7:192.168.20.150:rocep11s0:mlx5_0"
    "ubunturdma8:192.168.30.94:rocep11s0:mlx5_0"
)

tune_nic() {
    local hostname=$1
    local ip=$2
    local rdma_dev=$3
    local mlx_dev=$4

    echo "=== Tuning $hostname ($ip) ==="

    sshpass -p '<PASSWORD>' ssh -o StrictHostKeyChecking=no versa@${ip} << 'TUNE_EOF'

echo "1. Current ECN/DCQCN Settings:"
sudo rdma system show netns
sudo rdma statistic show link rocep*/1 | grep -E "cnp|ecn" | head -5

echo ""
echo "2. Setting Optimal DCQCN Parameters for AI Training:"

# Enable ECN on RoCE traffic
sudo sysctl -w net.ipv4.tcp_ecn=1

# RoCE CNP (Congestion Notification Packet) tuning
# These control how aggressively NICs respond to congestion
sudo mlxconfig -d /dev/mst/mt4115_pciconf0 set ROCE_CC_PRIO_MASK_P1=0x08  # Enable on priority 3
sudo mlxconfig -d /dev/mst/mt4115_pciconf0 set ROCE_CC_ALGORITHM_P1=2     # DCQCN algorithm

echo ""
echo "3. Reducing TX Queue Depth (prevent bursts):"
# Reduce ring buffer to prevent large bursts
sudo ethtool -G ens224 tx 512 rx 2048 2>/dev/null || echo "ethtool not applicable"

echo ""
echo "4. Current PFC Settings on NIC:"
sudo mlxconfig -d /dev/mst/mt4115_pciconf0 query | grep -i pfc

echo ""
echo "5. Setting PFC Priority:"
sudo mlxconfig -d /dev/mst/mt4115_pciconf0 set LOSSLESS_PRIO_MASK_RX_P1=0x08  # PFC on prio 3 RX
sudo mlxconfig -d /dev/mst/mt4115_pciconf0 set LOSSLESS_PRIO_MASK_TX_P1=0x08  # PFC on prio 3 TX

echo ""
echo "6. Rate Limiter Settings (prevent overwhelming switch):"
# These might need reboot to take effect
echo "Note: mlxconfig changes require NIC reset/reboot to take effect"

echo ""
echo "=== Tuning Complete for $hostname ==="

TUNE_EOF

    echo ""
}

# Tune all servers
for server_info in "${servers[@]}"; do
    IFS=':' read -r hostname ip rdma_dev mlx_dev <<< "$server_info"
    tune_nic "$hostname" "$ip" "$rdma_dev" "$mlx_dev"
done

echo ""
echo "=== Summary ==="
echo "NIC tuning applied to all 8 servers"
echo ""
echo "Next Steps:"
echo "1. Reboot servers for mlxconfig changes to take effect"
echo "2. Re-test with AI training workload"
echo "3. Monitor ingress drops on switch"
echo "4. Verify CNP handling increases"
