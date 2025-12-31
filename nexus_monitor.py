#!/usr/bin/env python3
"""
Cisco Nexus Interface Statistics Monitor
Collects interface statistics every 1 second using NX-API
"""

import requests
import json
import time
from datetime import datetime
from urllib3.exceptions import InsecureRequestWarning
import argparse

# Disable SSL warnings (switch uses self-signed cert)
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)


class NexusMonitor:
    def __init__(self, host, username, password, interfaces=None):
        self.host = host
        self.url = f"https://{host}/ins"
        self.auth = (username, password)
        self.headers = {
            'content-type': 'application/json'
        }
        self.interfaces = interfaces or []
        self.previous_stats = {}

    def send_command(self, command):
        """Send CLI command via NX-API"""
        payload = {
            "ins_api": {
                "version": "1.0",
                "type": "cli_show",
                "chunk": "0",
                "sid": "1",
                "input": command,
                "output_format": "json"
            }
        }

        try:
            response = requests.post(
                self.url,
                data=json.dumps(payload),
                headers=self.headers,
                auth=self.auth,
                verify=False,
                timeout=5
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error sending command: {e}")
            return None

    def get_interface_stats(self, interface):
        """Get interface statistics"""
        command = f"show interface {interface}"
        result = self.send_command(command)

        if not result:
            return None

        try:
            body = result['ins_api']['outputs']['output']['body']
            iface_data = body.get('TABLE_interface', {}).get('ROW_interface')
            return iface_data
        except Exception as e:
            print(f"Error parsing response for {interface}: {e}")
            return None

    def calculate_rates(self, interface, current_stats):
        """Calculate per-second rates"""
        if interface not in self.previous_stats:
            self.previous_stats[interface] = {
                'stats': current_stats,
                'timestamp': time.time()
            }
            return None

        prev = self.previous_stats[interface]
        time_delta = time.time() - prev['timestamp']

        if time_delta < 0.1:  # Avoid division by very small numbers
            return None

        rates = {}

        try:
            # Calculate byte rates
            if 'eth_inbytes' in current_stats and 'eth_inbytes' in prev['stats']:
                rx_bytes_delta = int(current_stats['eth_inbytes']) - int(prev['stats']['eth_inbytes'])
                if rx_bytes_delta >= 0:  # Handle counter wraps
                    rates['rx_mbps'] = (rx_bytes_delta * 8) / (time_delta * 1_000_000)
                    rates['rx_bytes_per_sec'] = rx_bytes_delta / time_delta

            if 'eth_outbytes' in current_stats and 'eth_outbytes' in prev['stats']:
                tx_bytes_delta = int(current_stats['eth_outbytes']) - int(prev['stats']['eth_outbytes'])
                if tx_bytes_delta >= 0:  # Handle counter wraps
                    rates['tx_mbps'] = (tx_bytes_delta * 8) / (time_delta * 1_000_000)
                    rates['tx_bytes_per_sec'] = tx_bytes_delta / time_delta

            # Calculate packet rates
            if 'eth_inucast' in current_stats and 'eth_inucast' in prev['stats']:
                rx_pkt_delta = int(current_stats['eth_inucast']) - int(prev['stats']['eth_inucast'])
                if rx_pkt_delta >= 0:
                    rates['rx_pps'] = rx_pkt_delta / time_delta

            if 'eth_outucast' in current_stats and 'eth_outucast' in prev['stats']:
                tx_pkt_delta = int(current_stats['eth_outucast']) - int(prev['stats']['eth_outucast'])
                if tx_pkt_delta >= 0:
                    rates['tx_pps'] = tx_pkt_delta / time_delta

            # Error counters
            if 'eth_inerr' in current_stats and 'eth_inerr' in prev['stats']:
                rx_err_delta = int(current_stats['eth_inerr']) - int(prev['stats']['eth_inerr'])
                if rx_err_delta > 0:
                    rates['rx_errors'] = rx_err_delta

            if 'eth_outerr' in current_stats and 'eth_outerr' in prev['stats']:
                tx_err_delta = int(current_stats['eth_outerr']) - int(prev['stats']['eth_outerr'])
                if tx_err_delta > 0:
                    rates['tx_errors'] = tx_err_delta

        except (KeyError, ValueError) as e:
            print(f"Error calculating rates for {interface}: {e}")

        # Update previous stats
        self.previous_stats[interface] = {
            'stats': current_stats,
            'timestamp': time.time()
        }

        return rates if rates else None

    def monitor_interfaces(self, interval=1, output_file=None):
        """Monitor interfaces continuously"""
        print(f"Monitoring Nexus Switch: {self.host}")
        print(f"Interval: {interval} second(s)")
        print(f"Interfaces: {', '.join(self.interfaces)}")
        print("-" * 120)

        # Optional file output
        file_handle = None
        if output_file:
            file_handle = open(output_file, 'a')
            file_handle.write(f"\n\n=== Monitoring started at {datetime.now()} ===\n")
            file_handle.flush()

        iteration = 0
        try:
            while True:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                iteration += 1

                output_lines = []
                output_lines.append(f"\n[{timestamp}] Iteration #{iteration}")
                output_lines.append("=" * 120)

                for interface in self.interfaces:
                    stats = self.get_interface_stats(interface)

                    if not stats:
                        line = f"  {interface:<15} : ERROR - Could not get stats"
                        output_lines.append(line)
                        continue

                    rates = self.calculate_rates(interface, stats)

                    # Display current stats
                    state = stats.get('state', 'unknown')
                    admin_state = stats.get('admin_state', 'unknown')
                    speed = stats.get('eth_speed', 'unknown')
                    duplex = stats.get('eth_duplex', 'unknown')

                    output_lines.append(f"\n  {interface:<15} | {admin_state}/{state} | {speed} {duplex}")

                    if rates:
                        rx_line = (f"    RX: {rates.get('rx_mbps', 0):>10.2f} Mbps | "
                                  f"{rates.get('rx_bytes_per_sec', 0):>12,.0f} B/s | "
                                  f"{rates.get('rx_pps', 0):>10,.0f} pps")
                        tx_line = (f"    TX: {rates.get('tx_mbps', 0):>10.2f} Mbps | "
                                  f"{rates.get('tx_bytes_per_sec', 0):>12,.0f} B/s | "
                                  f"{rates.get('tx_pps', 0):>10,.0f} pps")

                        output_lines.append(rx_line)
                        output_lines.append(tx_line)

                        # Show errors if any
                        if rates.get('rx_errors', 0) > 0 or rates.get('tx_errors', 0) > 0:
                            err_line = f"    ⚠️  ERRORS: RX={rates.get('rx_errors', 0)} TX={rates.get('tx_errors', 0)}"
                            output_lines.append(err_line)
                    else:
                        output_lines.append(f"    (Collecting baseline...)")

                # Print to console
                for line in output_lines:
                    print(line)

                # Write to file if specified
                if file_handle:
                    for line in output_lines:
                        file_handle.write(line + "\n")
                    file_handle.flush()

                time.sleep(interval)

        except KeyboardInterrupt:
            print("\n\nMonitoring stopped by user.")
        except Exception as e:
            print(f"\nError during monitoring: {e}")
            import traceback
            traceback.print_exc()
        finally:
            if file_handle:
                file_handle.close()


def expand_interface_range(interface_spec):
    """Expand interface range like 'Ethernet1/1/1-4' to individual interfaces"""
    interfaces = []

    # Split by comma first
    specs = [s.strip() for s in interface_spec.split(',')]

    for spec in specs:
        if '-' in spec:
            # Handle range like Ethernet1/1/1-4
            parts = spec.split('/')
            if len(parts) >= 3:
                prefix = '/'.join(parts[:-1])  # e.g., "Ethernet1/1"
                range_part = parts[-1]  # e.g., "1-4"

                if '-' in range_part:
                    start, end = range_part.split('-')
                    for i in range(int(start), int(end) + 1):
                        interfaces.append(f"{prefix}/{i}")
                else:
                    interfaces.append(spec)
            else:
                interfaces.append(spec)
        else:
            interfaces.append(spec)

    return interfaces


def main():
    parser = argparse.ArgumentParser(
        description='Monitor Cisco Nexus interface statistics via NX-API',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Monitor specific interfaces
  python3 nexus_monitor.py --host 192.168.50.229 --user admin --password 'Versa@123!!' \\
    --interfaces Ethernet1/1/1-4 Ethernet1/2/1-4

  # Monitor with 2 second interval
  python3 nexus_monitor.py --host 192.168.50.229 --user admin --password 'Versa@123!!' \\
    --interfaces Ethernet1/1/1-4 --interval 2

  # Save output to file
  python3 nexus_monitor.py --host 192.168.50.229 --user admin --password 'Versa@123!!' \\
    --interfaces Ethernet1/1/1-4 --output nexus_stats.log
        """
    )
    parser.add_argument('--host', required=True, help='Nexus switch IP or hostname')
    parser.add_argument('--user', required=True, help='Username')
    parser.add_argument('--password', required=True, help='Password')
    parser.add_argument('--interfaces', required=True, nargs='+',
                        help='Interface ranges (e.g., Ethernet1/1/1-4 Ethernet1/2/1-4)')
    parser.add_argument('--interval', type=float, default=1.0,
                        help='Polling interval in seconds (default: 1)')
    parser.add_argument('--output', help='Output file to save results')

    args = parser.parse_args()

    # Expand interface ranges
    all_interfaces = []
    for iface_spec in args.interfaces:
        all_interfaces.extend(expand_interface_range(iface_spec))

    print(f"Expanded interfaces: {all_interfaces}\n")

    monitor = NexusMonitor(
        host=args.host,
        username=args.user,
        password=args.password,
        interfaces=all_interfaces
    )

    monitor.monitor_interfaces(interval=args.interval, output_file=args.output)


if __name__ == "__main__":
    main()
