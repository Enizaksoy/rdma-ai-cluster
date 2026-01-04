#!/usr/bin/env python3
"""
RDMA Metrics Exporter for Prometheus
Collects RDMA statistics, PFC pause frames, and ECN metrics
Runs on port 9101
"""

import subprocess
import re
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

class RDMAMetricsCollector:
    """Collects RDMA, PFC, and ECN metrics"""

    def __init__(self):
        self.rdma_devices = self.detect_rdma_devices()
        self.network_interfaces = self.detect_network_interfaces()

    def detect_rdma_devices(self):
        """Detect RDMA devices on the system"""
        try:
            result = subprocess.run(['rdma', 'link', 'show'],
                                  capture_output=True, text=True, timeout=5)
            devices = []
            for line in result.stdout.split('\n'):
                if 'link' in line and 'state ACTIVE' in line:
                    match = re.search(r'link\s+(\S+)/\d+', line)
                    if match:
                        devices.append(match.group(1))
            return devices
        except Exception:
            return []

    def detect_network_interfaces(self):
        """Detect network interfaces associated with RDMA"""
        try:
            result = subprocess.run(['ip', 'link', 'show'],
                                  capture_output=True, text=True, timeout=5)
            interfaces = []
            for line in result.stdout.split('\n'):
                if 'ens' in line or 'eth' in line:
                    match = re.search(r'^\d+:\s+(\w+):', line)
                    if match:
                        interfaces.append(match.group(1))
            return interfaces
        except Exception:
            return []

    def get_rdma_statistics(self, device):
        """Get RDMA statistics for a device"""
        metrics = {}
        try:
            result = subprocess.run(['rdma', 'statistic', 'show', 'link', f'{device}/1'],
                                  capture_output=True, text=True, timeout=5)

            # Parse RDMA statistics
            for line in result.stdout.split('\n'):
                # ECN statistics
                if 'np_ecn_marked_roce_packets' in line:
                    match = re.search(r'np_ecn_marked_roce_packets\s+(\d+)', line)
                    if match:
                        metrics['ecn_marked_packets'] = int(match.group(1))

                if 'np_cnp_sent' in line:
                    match = re.search(r'np_cnp_sent\s+(\d+)', line)
                    if match:
                        metrics['cnp_sent'] = int(match.group(1))

                if 'rp_cnp_handled' in line:
                    match = re.search(r'rp_cnp_handled\s+(\d+)', line)
                    if match:
                        metrics['cnp_handled'] = int(match.group(1))

                if 'rp_cnp_ignored' in line:
                    match = re.search(r'rp_cnp_ignored\s+(\d+)', line)
                    if match:
                        metrics['cnp_ignored'] = int(match.group(1))

                # RDMA operations
                if 'rx_write_requests' in line:
                    match = re.search(r'rx_write_requests\s+(\d+)', line)
                    if match:
                        metrics['rx_write_requests'] = int(match.group(1))

                if 'tx_write_requests' in line:
                    match = re.search(r'tx_write_requests\s+(\d+)', line)
                    if match:
                        metrics['tx_write_requests'] = int(match.group(1))

                if 'rx_read_requests' in line:
                    match = re.search(r'rx_read_requests\s+(\d+)', line)
                    if match:
                        metrics['rx_read_requests'] = int(match.group(1))

                if 'tx_read_requests' in line:
                    match = re.search(r'tx_read_requests\s+(\d+)', line)
                    if match:
                        metrics['tx_read_requests'] = int(match.group(1))

        except Exception:
            pass

        return metrics

    def get_pfc_statistics(self, interface):
        """Get PFC (pause frame) statistics for an interface"""
        metrics = {}
        try:
            result = subprocess.run(['ethtool', '-S', interface],
                                  capture_output=True, text=True, timeout=5)

            for line in result.stdout.split('\n'):
                # RX PFC frames per priority
                for prio in range(8):
                    if f'rx_pfc_frames_prio{prio}' in line.lower() or f'rx_prio{prio}_pause' in line.lower():
                        match = re.search(r':\s*(\d+)', line)
                        if match:
                            metrics[f'rx_pfc_prio{prio}'] = int(match.group(1))

                # TX PFC frames per priority
                for prio in range(8):
                    if f'tx_pfc_frames_prio{prio}' in line.lower() or f'tx_prio{prio}_pause' in line.lower():
                        match = re.search(r':\s*(\d+)', line)
                        if match:
                            metrics[f'tx_pfc_prio{prio}'] = int(match.group(1))

                # Global pause frames
                if 'rx_pause_ctrl_phy' in line.lower():
                    match = re.search(r':\s*(\d+)', line)
                    if match:
                        metrics['rx_pause_global'] = int(match.group(1))

                if 'tx_pause_ctrl_phy' in line.lower():
                    match = re.search(r':\s*(\d+)', line)
                    if match:
                        metrics['tx_pause_global'] = int(match.group(1))

        except Exception:
            pass

        return metrics

    def get_network_statistics(self, interface):
        """Get general network statistics"""
        metrics = {}
        try:
            result = subprocess.run(['cat', f'/sys/class/net/{interface}/statistics/rx_bytes'],
                                  capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                metrics['rx_bytes'] = int(result.stdout.strip())

            result = subprocess.run(['cat', f'/sys/class/net/{interface}/statistics/tx_bytes'],
                                  capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                metrics['tx_bytes'] = int(result.stdout.strip())

            result = subprocess.run(['cat', f'/sys/class/net/{interface}/statistics/rx_packets'],
                                  capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                metrics['rx_packets'] = int(result.stdout.strip())

            result = subprocess.run(['cat', f'/sys/class/net/{interface}/statistics/tx_packets'],
                                  capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                metrics['tx_packets'] = int(result.stdout.strip())

            result = subprocess.run(['cat', f'/sys/class/net/{interface}/statistics/rx_dropped'],
                                  capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                metrics['rx_dropped'] = int(result.stdout.strip())

            result = subprocess.run(['cat', f'/sys/class/net/{interface}/statistics/tx_dropped'],
                                  capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                metrics['tx_dropped'] = int(result.stdout.strip())

        except Exception:
            pass

        return metrics

    def collect_all_metrics(self):
        """Collect all metrics and return Prometheus format"""
        metrics_output = []

        # Add header
        metrics_output.append("# HELP rdma_ecn_marked_packets Number of ECN-marked RoCE packets received")
        metrics_output.append("# TYPE rdma_ecn_marked_packets counter")

        metrics_output.append("# HELP rdma_cnp_sent Number of CNP packets sent")
        metrics_output.append("# TYPE rdma_cnp_sent counter")

        metrics_output.append("# HELP rdma_cnp_handled Number of CNP packets handled")
        metrics_output.append("# TYPE rdma_cnp_handled counter")

        metrics_output.append("# HELP rdma_operations RDMA read/write operations")
        metrics_output.append("# TYPE rdma_operations counter")

        metrics_output.append("# HELP pfc_pause_frames PFC pause frames per priority")
        metrics_output.append("# TYPE pfc_pause_frames counter")

        metrics_output.append("# HELP network_bytes Network bytes transferred")
        metrics_output.append("# TYPE network_bytes counter")

        metrics_output.append("# HELP network_packets Network packets transferred")
        metrics_output.append("# TYPE network_packets counter")

        # Collect RDMA metrics
        for device in self.rdma_devices:
            rdma_stats = self.get_rdma_statistics(device)

            if 'ecn_marked_packets' in rdma_stats:
                metrics_output.append(f'rdma_ecn_marked_packets{{device="{device}"}} {rdma_stats["ecn_marked_packets"]}')

            if 'cnp_sent' in rdma_stats:
                metrics_output.append(f'rdma_cnp_sent{{device="{device}"}} {rdma_stats["cnp_sent"]}')

            if 'cnp_handled' in rdma_stats:
                metrics_output.append(f'rdma_cnp_handled{{device="{device}"}} {rdma_stats["cnp_handled"]}')

            if 'cnp_ignored' in rdma_stats:
                metrics_output.append(f'rdma_cnp_ignored{{device="{device}"}} {rdma_stats["cnp_ignored"]}')

            for op in ['rx_write_requests', 'tx_write_requests', 'rx_read_requests', 'tx_read_requests']:
                if op in rdma_stats:
                    metrics_output.append(f'rdma_operations{{device="{device}",operation="{op}"}} {rdma_stats[op]}')

        # Collect PFC and network metrics
        for interface in self.network_interfaces:
            pfc_stats = self.get_pfc_statistics(interface)
            net_stats = self.get_network_statistics(interface)

            # PFC metrics
            for prio in range(8):
                if f'rx_pfc_prio{prio}' in pfc_stats:
                    metrics_output.append(f'pfc_pause_frames{{interface="{interface}",priority="{prio}",direction="rx"}} {pfc_stats[f"rx_pfc_prio{prio}"]}')

                if f'tx_pfc_prio{prio}' in pfc_stats:
                    metrics_output.append(f'pfc_pause_frames{{interface="{interface}",priority="{prio}",direction="tx"}} {pfc_stats[f"tx_pfc_prio{prio}"]}')

            if 'rx_pause_global' in pfc_stats:
                metrics_output.append(f'pfc_pause_frames{{interface="{interface}",priority="global",direction="rx"}} {pfc_stats["rx_pause_global"]}')

            if 'tx_pause_global' in pfc_stats:
                metrics_output.append(f'pfc_pause_frames{{interface="{interface}",priority="global",direction="tx"}} {pfc_stats["tx_pause_global"]}')

            # Network metrics
            for metric_name, metric_value in net_stats.items():
                if 'bytes' in metric_name:
                    direction = 'rx' if 'rx' in metric_name else 'tx'
                    metrics_output.append(f'network_bytes{{interface="{interface}",direction="{direction}"}} {metric_value}')
                elif 'packets' in metric_name:
                    direction = 'rx' if 'rx' in metric_name else 'tx'
                    metrics_output.append(f'network_packets{{interface="{interface}",direction="{direction}"}} {metric_value}')
                elif 'dropped' in metric_name:
                    direction = 'rx' if 'rx' in metric_name else 'tx'
                    metrics_output.append(f'network_packets_dropped{{interface="{interface}",direction="{direction}"}} {metric_value}')

        return '\n'.join(metrics_output) + '\n'


class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler for Prometheus metrics endpoint"""

    collector = RDMAMetricsCollector()

    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain; charset=utf-8')
            self.end_headers()

            metrics = self.collector.collect_all_metrics()
            self.wfile.write(metrics.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        """Suppress logging"""
        pass


def run_server(port=9101):
    """Run the metrics HTTP server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, MetricsHandler)
    print(f"RDMA Metrics Exporter running on port {port}")
    print(f"Metrics endpoint: http://localhost:{port}/metrics")
    print(f"Detected RDMA devices: {MetricsHandler.collector.rdma_devices}")
    print(f"Detected network interfaces: {MetricsHandler.collector.network_interfaces}")
    httpd.serve_forever()


if __name__ == '__main__':
    try:
        run_server(9101)
    except KeyboardInterrupt:
        print("\nShutting down...")
    except Exception as e:
        print(f"Error: {e}")
