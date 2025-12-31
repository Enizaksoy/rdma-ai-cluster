#!/bin/bash

#############################################
# Network Monitoring Script
# Monitors RDMA statistics, PFC, ECN
# during intensive training
#############################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVERS=(
    "192.168.11.152:ubunturdma1:ens224"
    "192.168.11.153:ubunturdma2:ens192"
    "192.168.11.154:ubunturdma3:ens224"
    "192.168.11.155:ubunturdma4:ens192"
    "192.168.11.107:ubunturdma5:ens192"
    "192.168.12.51:ubunturdma6:ens192"
    "192.168.20.150:ubunturdma7:ens192"
    "192.168.30.94:ubunturdma8:ens192"
)

DURATION=${1:-300}
INTERVAL=10

OUTPUT_FILE="/mnt/c/Users/eniza/Documents/claudechats/network_monitor_$(date +%Y%m%d_%H%M%S).log"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

create_expect_script() {
    cat > /tmp/ssh_cmd.exp << 'EOF'
#!/usr/bin/expect -f
set ip [lindex $argv 0]
set cmd [lindex $argv 1]
set timeout 30
spawn ssh -o StrictHostKeyChecking=no versa@$ip "$cmd"
expect {
    "password:" {
        send "<PASSWORD>\r"
        exp_continue
    }
    eof
}
EOF
    chmod +x /tmp/ssh_cmd.exp
}

ssh_exec() {
    expect /tmp/ssh_cmd.exp "$1" "$2" 2>/dev/null
}

create_expect_script

exec > >(tee "$OUTPUT_FILE")

print_header "Network Monitoring - RDMA/PFC/ECN Statistics"

echo ""
echo "Monitoring Duration: ${DURATION} seconds"
echo "Sample Interval: ${INTERVAL} seconds"
echo "Output File: $OUTPUT_FILE"
echo ""

start_time=$(date +%s)
sample=0

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ $elapsed -ge $DURATION ]; then
        break
    fi

    ((sample++))

    echo ""
    echo "========================================"
    echo "Sample #$sample - Time: $(date '+%H:%M:%S') - Elapsed: ${elapsed}s"
    echo "========================================"
    echo ""

    #############################################
    # Monitor each server
    #############################################
    for server_entry in "${SERVERS[@]}"; do
        IFS=':' read -r ip hostname iface <<< "$server_entry"

        echo "--- $hostname ($ip) - Interface: $iface ---"

        # Network interface statistics
        stats=$(ssh_exec "$ip" "cat /sys/class/net/$iface/statistics/{rx_bytes,tx_bytes,rx_packets,tx_packets,rx_dropped,tx_dropped} 2>/dev/null | paste -sd ' '")

        if [ ! -z "$stats" ]; then
            read rx_bytes tx_bytes rx_packets tx_packets rx_dropped tx_dropped <<< "$stats"

            rx_mbytes=$((rx_bytes / 1048576))
            tx_mbytes=$((tx_bytes / 1048576))

            echo "  Traffic: RX ${rx_mbytes}MB (${rx_packets} pkts), TX ${tx_mbytes}MB (${tx_packets} pkts)"
            echo "  Drops: RX ${rx_dropped}, TX ${tx_dropped}"
        fi

        # RDMA counters (if available)
        rdma_device=$(ssh_exec "$ip" "ibv_devices 2>/dev/null | grep roce | head -1 | awk '{print \$1}'")
        rdma_device=$(echo $rdma_device | tr -d '\r\n' | awk '{print $NF}')

        if [ ! -z "$rdma_device" ]; then
            # Port counters
            port_stats=$(ssh_exec "$ip" "cat /sys/class/infiniband/$rdma_device/ports/1/counters/{port_rcv_data,port_xmit_data,port_rcv_packets,port_xmit_packets} 2>/dev/null | paste -sd ' '")

            if [ ! -z "$port_stats" ]; then
                read rcv_data xmit_data rcv_pkts xmit_pkts <<< "$port_stats"

                # Convert to MB (counters are in 4-byte words)
                rcv_mb=$((rcv_data * 4 / 1048576))
                xmit_mb=$((xmit_data * 4 / 1048576))

                echo "  RDMA: RX ${rcv_mb}MB (${rcv_pkts} pkts), TX ${xmit_mb}MB (${xmit_pkts} pkts)"
            fi

            # Error counters
            error_stats=$(ssh_exec "$ip" "cat /sys/class/infiniband/$rdma_device/ports/1/counters/{port_rcv_errors,port_xmit_discards,symbol_error,link_error_recovery} 2>/dev/null | paste -sd ' '")

            if [ ! -z "$error_stats" ]; then
                read rcv_err xmit_disc sym_err link_err <<< "$error_stats"

                if [ "$rcv_err" != "0" ] || [ "$xmit_disc" != "0" ] || [ "$sym_err" != "0" ] || [ "$link_err" != "0" ]; then
                    echo -e "  ${RED}Errors: RX Err=${rcv_err}, TX Disc=${xmit_disc}, Sym Err=${sym_err}, Link Err=${link_err}${NC}"
                else
                    echo -e "  ${GREEN}Errors: None${NC}"
                fi
            fi

            # Check for RoCE CNP (Congestion Notification Packets - ECN related)
            cnp_stats=$(ssh_exec "$ip" "cat /sys/class/infiniband/$rdma_device/ports/1/counters/{rx_icrc_encapsulated,rx_read_requests,rx_write_requests} 2>/dev/null | paste -sd ' '")

            if [ ! -z "$cnp_stats" ]; then
                read icrc reads writes <<< "$cnp_stats"
                echo "  RDMA Ops: Reads=${reads}, Writes=${writes}"
            fi
        fi

        # Ethtool statistics for PFC/ECN (if available)
        pfc_stats=$(ssh_exec "$ip" "sudo ethtool -S $iface 2>/dev/null | grep -E 'pfc|pause' | head -5")
        if [ ! -z "$pfc_stats" ]; then
            echo "  PFC Stats:"
            echo "$pfc_stats" | sed 's/^/    /'
        fi

        echo ""
    done

    echo "Waiting ${INTERVAL} seconds for next sample..."
    sleep $INTERVAL
done

print_header "Monitoring Complete"

echo ""
echo "Total Samples: $sample"
echo "Total Duration: $elapsed seconds"
echo "Results saved to: $OUTPUT_FILE"
echo ""
echo "To analyze results:"
echo "  grep 'RDMA:' $OUTPUT_FILE"
echo "  grep 'Errors:' $OUTPUT_FILE"
echo "  grep 'PFC' $OUTPUT_FILE"
echo ""

rm -f /tmp/ssh_cmd.exp
