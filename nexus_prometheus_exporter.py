#!/usr/bin/env python3
"""
Nexus Switch Prometheus Exporter
Exposes switch metrics for Grafana visualization
"""

from flask import Flask, Response
import requests
import json
import re
from urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

app = Flask(__name__)

# Configuration
SWITCH_IP = "192.168.50.229"
USERNAME = "admin"
PASSWORD = "Versa@123!!"
INTERFACES = [
    "ethernet1/1/1", "ethernet1/1/2", "ethernet1/2/1", "ethernet1/2/2",  # Physical ports
    "ii1/1/1", "ii1/1/2", "ii1/1/3", "ii1/1/4", "ii1/1/5", "ii1/1/6"     # Internal fabric
]

def get_switch_data(command):
    """Execute CLI command on Nexus switch via NX-API"""
    url = f"https://{SWITCH_IP}/ins"
    headers = {
        'content-type': 'application/json'
    }
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
            url,
            auth=(USERNAME, PASSWORD),
            headers=headers,
            json=payload,
            verify=False,
            timeout=10
        )
        if response.status_code == 200:
            return response.json()
        return None
    except Exception as e:
        print(f"Error querying switch: {e}")
        return None

def parse_pfc_stats():
    """Get PFC pause frame statistics"""
    metrics = []
    data = get_switch_data("show interface priority-flow-control")

    if data and 'ins_api' in data:
        try:
            body = data['ins_api']['outputs']['output']['body']
            if 'TABLE_module' in body:
                modules = body['TABLE_module']['ROW_module']
                if not isinstance(modules, list):
                    modules = [modules]

                for module in modules:
                    if 'TABLE_pfc_interface' in module:
                        interfaces = module['TABLE_pfc_interface']['ROW_pfc_interface']
                        if not isinstance(interfaces, list):
                            interfaces = [interfaces]

                        for intf in interfaces:
                            interface = intf.get('if_name_str', '')
                            # Export physical RDMA interfaces and internal fabric (ii) interfaces
                            if any(iface in interface.lower() for iface in ['ethernet1/1/1', 'ethernet1/1/2', 'ethernet1/2/1', 'ethernet1/2/2', 'ii1/1/']):
                                rx_stats = int(intf.get('rx-stats', 0))
                                tx_stats = int(intf.get('tx-stats', 0))

                                metrics.append(f'nexus_pfc_rx_pause{{interface="{interface}"}} {rx_stats}')
                                metrics.append(f'nexus_pfc_tx_pause{{interface="{interface}"}} {tx_stats}')
        except Exception as e:
            print(f"Error parsing PFC stats: {e}")

    return metrics

def parse_interface_counters():
    """Get interface counters"""
    metrics = []

    for interface in INTERFACES:
        data = get_switch_data(f"show interface {interface} counters")

        if data and 'ins_api' in data:
            try:
                body = data['ins_api']['outputs']['output']['body']
                if 'TABLE_rx_counters' in body:
                    rx_rows = body['TABLE_rx_counters']['ROW_rx_counters']
                    if not isinstance(rx_rows, list):
                        rx_rows = [rx_rows]

                    # Aggregate RX metrics from multiple rows
                    rx_unicast = 0
                    rx_multicast = 0
                    rx_broadcast = 0
                    rx_bytes = 0
                    for rx_data in rx_rows:
                        rx_unicast += int(rx_data.get('eth_inucast', 0))
                        rx_multicast += int(rx_data.get('eth_inmcast', 0))
                        rx_broadcast += int(rx_data.get('eth_inbcast', 0))
                        rx_bytes += int(rx_data.get('eth_inbytes', 0))

                    metrics.append(f'nexus_interface_rx_packets{{interface="{interface}",type="unicast"}} {rx_unicast}')
                    metrics.append(f'nexus_interface_rx_packets{{interface="{interface}",type="multicast"}} {rx_multicast}')
                    metrics.append(f'nexus_interface_rx_packets{{interface="{interface}",type="broadcast"}} {rx_broadcast}')
                    metrics.append(f'nexus_interface_rx_bytes{{interface="{interface}"}} {rx_bytes}')

                if 'TABLE_tx_counters' in body:
                    tx_rows = body['TABLE_tx_counters']['ROW_tx_counters']
                    if not isinstance(tx_rows, list):
                        tx_rows = [tx_rows]

                    # Aggregate TX metrics from multiple rows
                    tx_unicast = 0
                    tx_multicast = 0
                    tx_broadcast = 0
                    tx_bytes = 0
                    for tx_data in tx_rows:
                        tx_unicast += int(tx_data.get('eth_outucast', 0))
                        tx_multicast += int(tx_data.get('eth_outmcast', 0))
                        tx_broadcast += int(tx_data.get('eth_outbcast', 0))
                        tx_bytes += int(tx_data.get('eth_outbytes', 0))

                    metrics.append(f'nexus_interface_tx_packets{{interface="{interface}",type="unicast"}} {tx_unicast}')
                    metrics.append(f'nexus_interface_tx_packets{{interface="{interface}",type="multicast"}} {tx_multicast}')
                    metrics.append(f'nexus_interface_tx_packets{{interface="{interface}",type="broadcast"}} {tx_broadcast}')
                    metrics.append(f'nexus_interface_tx_bytes{{interface="{interface}"}} {tx_bytes}')
            except Exception as e:
                print(f"Error parsing interface {interface}: {e}")

    return metrics

def parse_queue_stats():
    """Get queuing statistics with TX traffic per QoS group"""
    metrics = []

    for interface in INTERFACES:
        data = get_switch_data(f"show queuing interface {interface}")

        if data and 'ins_api' in data:
            try:
                body = data['ins_api']['outputs']['output']['body']
                module_table = body.get('TABLE_module', {})
                module_row = module_table.get('ROW_module', {})
                queue_if_table = module_row.get('TABLE_queuing_interface', {})
                queue_if_rows = queue_if_table.get('ROW_queuing_interface', [])

                if isinstance(queue_if_rows, dict):
                    queue_if_rows = [queue_if_rows]

                for if_row in queue_if_rows:
                    if if_row.get('dir') != 'Egress':
                        continue

                    qos_stats_table = if_row.get('TABLE_qosgrp_egress_stats', {})
                    qos_stats_rows = qos_stats_table.get('ROW_qosgrp_egress_stats', [])

                    if isinstance(qos_stats_rows, dict):
                        qos_stats_rows = [qos_stats_rows]

                    for qos_group in qos_stats_rows:
                        qos_num = str(qos_group.get('eq-qosgrp', ''))
                        qos_label = qos_num
                        if qos_num == '5':
                            qos_label = 'control'
                        elif qos_num == '6':
                            qos_label = 'span'

                        stats_entry_table = qos_group.get('TABLE_qosgrp_egress_stats_entry', {})
                        stats_entries = stats_entry_table.get('ROW_qosgrp_egress_stats_entry', [])

                        if isinstance(stats_entries, dict):
                            stats_entries = [stats_entries]

                        tx_pkts = 0
                        tx_bytes = 0
                        dropped_pkts = 0
                        dropped_bytes = 0

                        for stat in stats_entries:
                            stat_type = stat.get('eq-stat-type', '')
                            stat_units = stat.get('eq-stat-units', '')
                            uc = int(stat.get('eq-uc-stat-value', 0))
                            oobfc = int(stat.get('eq-oobfc-uc-stat-value', 0))
                            mc = int(stat.get('eq-mc-stat-value', 0))
                            total = uc + oobfc + mc

                            if stat_type == 'Tx' and stat_units == 'Pkts':
                                tx_pkts = total
                            elif stat_type == 'Tx' and stat_units == 'Byts':
                                tx_bytes = total
                            elif stat_type == 'Dropped' and stat_units == 'Pkts':
                                dropped_pkts = total
                            elif stat_type == 'Dropped' and stat_units == 'Byts':
                                dropped_bytes = total

                        metrics.append(f'nexus_queue_tx_packets{{interface="{interface}",qos_group="{qos_label}"}} {tx_pkts}')
                        metrics.append(f'nexus_queue_tx_bytes{{interface="{interface}",qos_group="{qos_label}"}} {tx_bytes}')
                        metrics.append(f'nexus_queue_dropped_packets{{interface="{interface}",qos_group="{qos_label}"}} {dropped_pkts}')
                        metrics.append(f'nexus_queue_dropped_bytes{{interface="{interface}",qos_group="{qos_label}"}} {dropped_bytes}')

            except Exception as e:
                print(f"Error parsing queue stats for {interface}: {e}")

    return metrics

def parse_flowcontrol_stats():
    """Get flow control statistics"""
    metrics = []
    data = get_switch_data("show interface flowcontrol")

    if data and 'ins_api' in data:
        try:
            body = data['ins_api']['outputs']['output']['body']
            if 'TABLE_flowcontrol' in body:
                interfaces = body['TABLE_flowcontrol']['ROW_flowcontrol']
                if not isinstance(interfaces, list):
                    interfaces = [interfaces]

                for intf in interfaces:
                    interface = intf.get('interface', '')
                    # Export physical RDMA interfaces and internal fabric (ii) interfaces
                    if any(iface in interface.lower() for iface in ['ethernet1/1/1', 'ethernet1/1/2', 'ethernet1/2/1', 'ethernet1/2/2', 'ii1/1/']):
                        rx_pause = int(intf.get('rx-pause', 0))
                        tx_pause = int(intf.get('tx-pause', 0))

                        metrics.append(f'nexus_flowcontrol_rx_pause{{interface="{interface}"}} {rx_pause}')
                        metrics.append(f'nexus_flowcontrol_tx_pause{{interface="{interface}"}} {tx_pause}')
        except Exception as e:
            print(f"Error parsing flow control stats: {e}")

    return metrics

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    all_metrics = []

    # Collect all metrics
    all_metrics.extend(parse_pfc_stats())
    all_metrics.extend(parse_interface_counters())
    all_metrics.extend(parse_queue_stats())
    all_metrics.extend(parse_flowcontrol_stats())

    # Add metadata
    output = "# HELP nexus_pfc_rx_pause PFC pause frames received\n"
    output += "# TYPE nexus_pfc_rx_pause counter\n"
    output += "# HELP nexus_pfc_tx_pause PFC pause frames transmitted\n"
    output += "# TYPE nexus_pfc_tx_pause counter\n"
    output += "# HELP nexus_flowcontrol_rx_pause Flow control pause frames received\n"
    output += "# TYPE nexus_flowcontrol_rx_pause counter\n"
    output += "# HELP nexus_flowcontrol_tx_pause Flow control pause frames transmitted\n"
    output += "# TYPE nexus_flowcontrol_tx_pause counter\n"
    output += "# HELP nexus_interface_rx_bytes Interface RX bytes\n"
    output += "# TYPE nexus_interface_rx_bytes counter\n"
    output += "# HELP nexus_interface_tx_bytes Interface TX bytes\n"
    output += "# TYPE nexus_interface_tx_bytes counter\n"
    output += "# HELP nexus_interface_rx_packets Interface RX packets\n"
    output += "# TYPE nexus_interface_rx_packets counter\n"
    output += "# HELP nexus_interface_tx_packets Interface TX packets\n"
    output += "# TYPE nexus_interface_tx_packets counter\n"
    output += "# HELP nexus_queue_tx_packets Queue TX packets per QoS group\n"
    output += "# TYPE nexus_queue_tx_packets counter\n"
    output += "# HELP nexus_queue_tx_bytes Queue TX bytes per QoS group\n"
    output += "# TYPE nexus_queue_tx_bytes counter\n"
    output += "# HELP nexus_queue_dropped_packets Queue dropped packets per QoS group\n"
    output += "# TYPE nexus_queue_dropped_packets counter\n"
    output += "# HELP nexus_queue_dropped_bytes Queue dropped bytes per QoS group\n"
    output += "# TYPE nexus_queue_dropped_bytes counter\n"
    output += "\n"

    output += "\n".join(all_metrics)
    output += "\n"

    return Response(output, mimetype='text/plain')

@app.route('/health')
def health():
    """Health check endpoint"""
    return "OK"

if __name__ == '__main__':
    print("=" * 60)
    print("  Nexus Switch Prometheus Exporter")
    print("=" * 60)
    print(f"  Switch: {SWITCH_IP}")
    print(f"  Interfaces: {', '.join(INTERFACES)}")
    print(f"  Metrics endpoint: http://0.0.0.0:9102/metrics")
    print("=" * 60)
    print()

    app.run(host='0.0.0.0', port=9102, debug=False)
