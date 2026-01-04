#!/usr/bin/env python3
"""
ESXi Statistics Exporter for Prometheus
Collects pause frame statistics from ESXi hosts
"""

from flask import Flask, Response
import subprocess
import re

app = Flask(__name__)

# ESXi Host Configuration
ESXI_HOSTS = {
    "esxi1": {
        "ip": "192.168.50.32",
        "vmnics": ["vmnic5", "vmnic6"],
        "user": "root",
        "password": "Versa@123!!"
    },
    "esxi2": {
        "ip": "192.168.50.152",
        "vmnics": ["vmnic3", "vmnic4"],
        "user": "root",
        "password": "Versa@123!!"
    }
}

def get_esxi_pause_stats(host_name, host_config):
    """Get pause frame statistics from ESXi host"""
    metrics = []

    host_ip = host_config["ip"]
    user = host_config["user"]
    password = host_config["password"]

    for vmnic in host_config["vmnics"]:
        try:
            # Use sshpass to connect and get stats
            cmd = [
                'sshpass', '-p', password,
                'ssh', '-o', 'StrictHostKeyChecking=no',
                f'{user}@{host_ip}',
                f'vsish -e cat /net/pNics/{vmnic}/stats | grep -i pause'
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)

            if result.returncode == 0:
                output = result.stdout
            else:
                print(f"Error from {host_name} {vmnic}: returncode={result.returncode}")
                print(f"stderr: {result.stderr}")
                continue

                # Parse pause frame statistics
                stats_map = {
                    'rxPauseCtrlPhy': 'esxi_pause_rx_phy',
                    'txPauseCtrlPhy': 'esxi_pause_tx_phy',
                    'rx_global_pause': 'esxi_pause_rx_global',
                    'tx_global_pause': 'esxi_pause_tx_global',
                    'rx_global_pause_duration': 'esxi_pause_rx_duration',
                    'tx_global_pause_duration': 'esxi_pause_tx_duration',
                    'rx_global_pause_transition': 'esxi_pause_rx_transitions',
                    'txPauseStormWarningEvents': 'esxi_pause_storm_warnings',
                    'txPauseStormErrorEvents': 'esxi_pause_storm_errors',
                }

                for stat_name, metric_name in stats_map.items():
                    match = re.search(rf'{stat_name}:\s+(\d+)', output)
                    if match:
                        value = match.group(1)
                        metrics.append(
                            f'{metric_name}{{host="{host_name}",vmnic="{vmnic}",esxi_ip="{host_ip}"}} {value}'
                        )

        except subprocess.TimeoutExpired:
            print(f"Timeout getting stats from {host_name} {vmnic}")
        except Exception as e:
            print(f"Error getting stats from {host_name} {vmnic}: {e}")

    return metrics

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    output = []

    # Add metric descriptions
    output.append('# HELP esxi_pause_rx_phy ESXi physical RX pause frames')
    output.append('# TYPE esxi_pause_rx_phy counter')
    output.append('# HELP esxi_pause_tx_phy ESXi physical TX pause frames')
    output.append('# TYPE esxi_pause_tx_phy counter')
    output.append('# HELP esxi_pause_rx_global ESXi global RX pause frames')
    output.append('# TYPE esxi_pause_rx_global counter')
    output.append('# HELP esxi_pause_tx_global ESXi global TX pause frames')
    output.append('# TYPE esxi_pause_tx_global counter')
    output.append('# HELP esxi_pause_rx_duration ESXi RX pause duration (units)')
    output.append('# TYPE esxi_pause_rx_duration counter')
    output.append('# HELP esxi_pause_rx_transitions ESXi RX pause state transitions')
    output.append('# TYPE esxi_pause_rx_transitions counter')
    output.append('# HELP esxi_pause_storm_warnings ESXi pause storm warning events')
    output.append('# TYPE esxi_pause_storm_warnings counter')
    output.append('# HELP esxi_pause_storm_errors ESXi pause storm error events')
    output.append('# TYPE esxi_pause_storm_errors counter')
    output.append('')

    # Collect metrics from all ESXi hosts
    for host_name, host_config in ESXI_HOSTS.items():
        host_metrics = get_esxi_pause_stats(host_name, host_config)
        output.extend(host_metrics)

    return Response('\n'.join(output) + '\n', mimetype='text/plain')

@app.route('/health')
def health():
    """Health check endpoint"""
    return 'OK'

if __name__ == '__main__':
    print("Starting ESXi Statistics Exporter...")
    print("Monitoring ESXi hosts:")
    for name, config in ESXI_HOSTS.items():
        print(f"  {name}: {config['ip']} - vmnics: {', '.join(config['vmnics'])}")
    print("\nListening on http://0.0.0.0:9104/metrics")
    app.run(host='0.0.0.0', port=9104)
