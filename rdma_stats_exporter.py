#!/usr/bin/env python3
"""
RDMA Statistics Exporter for Prometheus
Exports RoCE/RDMA metrics including ECN and CNP statistics
"""

from flask import Flask, Response
import subprocess
import re
import time

app = Flask(__name__)

# RDMA device to monitor
RDMA_DEVICE = "rocep11s0"  # Will auto-detect if not found
RDMA_PORT = "1"

def get_rdma_device():
    """Auto-detect RDMA device"""
    try:
        result = subprocess.run(['rdma', 'link', 'show'],
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            # Parse output like: "link rocep11s0/1 state ACTIVE"
            match = re.search(r'link (\w+)/(\d+)', result.stdout)
            if match:
                return match.group(1), match.group(2)
    except Exception as e:
        print(f"Error detecting RDMA device: {e}")

    return RDMA_DEVICE, RDMA_PORT

def parse_rdma_stats():
    """Parse RDMA statistics from rdma tool"""
    metrics = []

    device, port = get_rdma_device()

    try:
        # Get RDMA link statistics
        result = subprocess.run(
            ['rdma', 'statistic', 'show', 'link', f'{device}/{port}'],
            capture_output=True, text=True, timeout=5
        )

        if result.returncode != 0:
            print(f"Error getting RDMA stats: {result.stderr}")
            return metrics

        output = result.stdout

        # Parse key statistics
        stats_map = {
            'rx_write_requests': 'rdma_rx_write_requests',
            'rx_read_requests': 'rdma_rx_read_requests',
            'out_of_sequence': 'rdma_out_of_sequence',
            'packet_seq_err': 'rdma_packet_seq_err',
            'local_ack_timeout_err': 'rdma_ack_timeout_err',

            # ECN/CNP statistics (key metrics!)
            'np_ecn_marked_roce_packets': 'rdma_ecn_marked_packets',
            'np_cnp_sent': 'rdma_cnp_sent',
            'rp_cnp_handled': 'rdma_cnp_handled',
            'rp_cnp_ignored': 'rdma_cnp_ignored',
        }

        for stat_name, metric_name in stats_map.items():
            # Use regex to find the statistic value
            match = re.search(rf'{stat_name}\s+(\d+)', output)
            if match:
                value = match.group(1)
                metrics.append(f'{metric_name}{{device="{device}",port="{port}"}} {value}')

    except subprocess.TimeoutExpired:
        print("Timeout getting RDMA stats")
    except Exception as e:
        print(f"Error parsing RDMA stats: {e}")

    return metrics

def get_interface_stats():
    """Get network interface statistics"""
    metrics = []

    try:
        # Try to find RDMA interface (usually ens224, ens192, etc.)
        result = subprocess.run(['ip', '-s', 'link'],
                              capture_output=True, text=True, timeout=5)

        if result.returncode == 0:
            lines = result.stdout.split('\n')
            current_iface = None

            for i, line in enumerate(lines):
                # Match interface name like "ens224:"
                if_match = re.match(r'^\d+:\s+(\w+):', line)
                if if_match:
                    current_iface = if_match.group(1)

                # Parse RX/TX stats
                if current_iface and 'RX:' in line and i+1 < len(lines):
                    stats_line = lines[i+1].strip()
                    parts = stats_line.split()
                    if len(parts) >= 2:
                        rx_bytes = parts[0]
                        rx_packets = parts[1]
                        metrics.append(f'rdma_interface_rx_bytes{{interface="{current_iface}"}} {rx_bytes}')
                        metrics.append(f'rdma_interface_rx_packets{{interface="{current_iface}"}} {rx_packets}')

                if current_iface and 'TX:' in line and i+1 < len(lines):
                    stats_line = lines[i+1].strip()
                    parts = stats_line.split()
                    if len(parts) >= 2:
                        tx_bytes = parts[0]
                        tx_packets = parts[1]
                        metrics.append(f'rdma_interface_tx_bytes{{interface="{current_iface}"}} {tx_bytes}')
                        metrics.append(f'rdma_interface_tx_packets{{interface="{current_iface}"}} {tx_packets}')

    except Exception as e:
        print(f"Error getting interface stats: {e}")

    return metrics

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    output = []

    # RDMA statistics
    output.append('# HELP rdma_ecn_marked_packets ECN-marked RoCE packets')
    output.append('# TYPE rdma_ecn_marked_packets counter')
    output.append('# HELP rdma_cnp_sent CNP packets sent')
    output.append('# TYPE rdma_cnp_sent counter')
    output.append('# HELP rdma_cnp_handled CNP packets received and handled')
    output.append('# TYPE rdma_cnp_handled counter')
    output.append('# HELP rdma_cnp_ignored CNP packets ignored')
    output.append('# TYPE rdma_cnp_ignored counter')
    output.append('# HELP rdma_rx_write_requests RDMA write requests received')
    output.append('# TYPE rdma_rx_write_requests counter')
    output.append('# HELP rdma_rx_read_requests RDMA read requests received')
    output.append('# TYPE rdma_rx_read_requests counter')

    # Collect metrics
    rdma_metrics = parse_rdma_stats()
    output.extend(rdma_metrics)

    # Add interface stats
    output.append('')
    output.append('# HELP rdma_interface_rx_bytes Interface RX bytes')
    output.append('# TYPE rdma_interface_rx_bytes counter')
    output.append('# HELP rdma_interface_tx_bytes Interface TX bytes')
    output.append('# TYPE rdma_interface_tx_bytes counter')

    iface_metrics = get_interface_stats()
    output.extend(iface_metrics)

    return Response('\n'.join(output) + '\n', mimetype='text/plain')

@app.route('/health')
def health():
    """Health check endpoint"""
    return 'OK'

if __name__ == '__main__':
    print("Starting RDMA Statistics Exporter...")
    device, port = get_rdma_device()
    print(f"Monitoring RDMA device: {device}/{port}")
    print("Listening on http://0.0.0.0:9103/metrics")
    app.run(host='0.0.0.0', port=9103)
