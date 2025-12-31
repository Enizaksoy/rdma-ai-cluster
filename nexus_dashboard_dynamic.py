#!/usr/bin/env python3
"""
Nexus Network Monitor - Dynamic Interface Selection
Add/remove interfaces from web UI
"""

from flask import Flask, render_template_string, jsonify, request
import requests
import json
from collections import deque, defaultdict
from threading import Thread, Lock
import time
from urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

app = Flask(__name__)

# Config
SWITCH_IP = "192.168.50.229"
USERNAME = "admin"
PASSWORD = "<PASSWORD>"

# QoS Group Colors
QOS_COLORS = {
    '0': {'color': '#3b82f6', 'name': 'QoS Group 0'},
    '1': {'color': '#10b981', 'name': 'QoS Group 1'},
    '2': {'color': '#f59e0b', 'name': 'QoS Group 2'},
    '3': {'color': '#ef4444', 'name': 'QoS Group 3'},
    'control': {'color': '#8b5cf6', 'name': 'Control'},
    'span': {'color': '#ec4899', 'name': 'SPAN'}
}

# Dynamic interface list
data_lock = Lock()
monitored_interfaces = []  # User-selected interfaces
interface_data = {}
previous_stats = {}
previous_queue_stats = {}


def init_interface_data(interface):
    """Initialize data storage for an interface"""
    interface_data[interface] = {
        'timestamps': deque(maxlen=120),
        'rx_mbps': deque(maxlen=120),
        'tx_mbps': deque(maxlen=120),
        'current_rx': 0,
        'current_tx': 0,
        'queues': {}
    }
    for qos_group in ['0', '1', '2', '3', 'control', 'span']:
        interface_data[interface]['queues'][qos_group] = {
            'tx_pkts': deque(maxlen=120),
            'tx_bytes': deque(maxlen=120),
            'dropped_pkts': deque(maxlen=120),
            'current_tx_pkts': 0,
            'current_tx_bytes': 0,
            'current_dropped': 0
        }


def send_nxapi_command(command, output_format="json"):
    """Send command to Nexus switch"""
    url = f"https://{SWITCH_IP}/ins"
    cmd_type = "cli_show" if output_format == "json" else "cli_show_ascii"

    payload = {
        "ins_api": {
            "version": "1.0",
            "type": cmd_type,
            "chunk": "0",
            "sid": "1",
            "input": command,
            "output_format": output_format
        }
    }

    try:
        response = requests.post(
            url,
            data=json.dumps(payload),
            headers={'content-type': 'application/json'},
            auth=(USERNAME, PASSWORD),
            verify=False,
            timeout=5
        )
        return response.json()
    except:
        return None


def get_all_interfaces():
    """Get list of all Ethernet interfaces from switch"""
    result = send_nxapi_command("show interface brief")
    if not result:
        return []

    try:
        body = result['ins_api']['outputs']['output']['body']
        interfaces_data = body.get('TABLE_interface', {}).get('ROW_interface', [])

        if isinstance(interfaces_data, dict):
            interfaces_data = [interfaces_data]

        interfaces = []
        for iface in interfaces_data:
            iface_name = iface.get('interface', '')
            if iface_name.startswith('Eth'):
                interfaces.append({
                    'name': iface_name,
                    'state': iface.get('state', 'unknown'),
                    'speed': iface.get('speed', 'unknown')
                })

        return sorted(interfaces, key=lambda x: x['name'])
    except:
        return []


def get_interface_stats(interface):
    """Get interface stats"""
    result = send_nxapi_command(f"show interface {interface}")
    if not result:
        return None

    try:
        body = result['ins_api']['outputs']['output']['body']
        return body.get('TABLE_interface', {}).get('ROW_interface')
    except:
        return None


def parse_queue_stats(interface):
    """Parse queue statistics from JSON output"""
    result = send_nxapi_command(f"show queuing interface {interface}", output_format="json")
    if not result:
        return {}

    try:
        body = result['ins_api']['outputs']['output']['body']
        module_table = body.get('TABLE_module', {})
        module_row = module_table.get('ROW_module', {})
        queue_if_table = module_row.get('TABLE_queuing_interface', {})
        queue_if_rows = queue_if_table.get('ROW_queuing_interface', [])

        if isinstance(queue_if_rows, dict):
            queue_if_rows = [queue_if_rows]

        queue_stats = {}

        for if_row in queue_if_rows:
            if if_row.get('dir') != 'Egress':
                continue

            qos_stats_table = if_row.get('TABLE_qosgrp_egress_stats', {})
            qos_stats_rows = qos_stats_table.get('ROW_qosgrp_egress_stats', [])

            if isinstance(qos_stats_rows, dict):
                qos_stats_rows = [qos_stats_rows]

            for qos_group in qos_stats_rows:
                qos_num = str(qos_group.get('eq-qosgrp', ''))
                qos_key = qos_num
                if qos_num == '5':
                    qos_key = 'control'
                elif qos_num == '6':
                    qos_key = 'span'

                stats_entry_table = qos_group.get('TABLE_qosgrp_egress_stats_entry', {})
                stats_entries = stats_entry_table.get('ROW_qosgrp_egress_stats_entry', [])

                if isinstance(stats_entries, dict):
                    stats_entries = [stats_entries]

                tx_pkts = 0
                tx_bytes = 0
                dropped_pkts = 0

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

                queue_stats[qos_key] = {
                    'tx_pkts': tx_pkts,
                    'tx_bytes': tx_bytes,
                    'dropped_pkts': dropped_pkts
                }

        for qos in ['0', '1', '2', '3', 'control', 'span']:
            if qos not in queue_stats:
                queue_stats[qos] = {'tx_pkts': 0, 'tx_bytes': 0, 'dropped_pkts': 0}

        return queue_stats
    except:
        return {}


def calculate_bandwidth(interface, current_stats):
    """Calculate bandwidth in Mbps"""
    global previous_stats

    if interface not in previous_stats:
        previous_stats[interface] = {
            'stats': current_stats,
            'time': time.time()
        }
        return None, None

    prev = previous_stats[interface]
    time_delta = time.time() - prev['time']

    if time_delta < 0.5:
        return None, None

    try:
        rx_bytes = int(current_stats.get('eth_inbytes', 0))
        tx_bytes = int(current_stats.get('eth_outbytes', 0))
        prev_rx = int(prev['stats'].get('eth_inbytes', 0))
        prev_tx = int(prev['stats'].get('eth_outbytes', 0))

        rx_mbps = ((rx_bytes - prev_rx) * 8) / (time_delta * 1_000_000)
        tx_mbps = ((tx_bytes - prev_tx) * 8) / (time_delta * 1_000_000)

        previous_stats[interface] = {
            'stats': current_stats,
            'time': time.time()
        }

        return max(0, rx_mbps), max(0, tx_mbps)
    except:
        return None, None


def calculate_queue_rates(interface, current_queues):
    """Calculate queue packet/byte rates"""
    global previous_queue_stats

    key = interface
    if key not in previous_queue_stats:
        previous_queue_stats[key] = {
            'queues': current_queues,
            'time': time.time()
        }
        return {}

    prev = previous_queue_stats[key]
    time_delta = time.time() - prev['time']

    if time_delta < 0.5:
        return {}

    rates = {}

    try:
        for qos_group, stats in current_queues.items():
            if qos_group in prev['queues']:
                prev_stats = prev['queues'][qos_group]

                tx_pkt_delta = max(0, stats['tx_pkts'] - prev_stats['tx_pkts'])
                tx_byte_delta = max(0, stats['tx_bytes'] - prev_stats['tx_bytes'])
                drop_delta = max(0, stats['dropped_pkts'] - prev_stats['dropped_pkts'])

                rates[qos_group] = {
                    'tx_pps': tx_pkt_delta / time_delta,
                    'tx_bps': (tx_byte_delta * 8) / time_delta,
                    'drop_pps': drop_delta / time_delta
                }

        previous_queue_stats[key] = {
            'queues': current_queues,
            'time': time.time()
        }

        return rates
    except:
        return {}


def monitor_loop():
    """Background monitoring thread"""
    while True:
        current_time = time.strftime('%H:%M:%S')

        with data_lock:
            interfaces_to_monitor = monitored_interfaces.copy()

        for interface in interfaces_to_monitor:
            # Ensure interface data exists
            if interface not in interface_data:
                with data_lock:
                    init_interface_data(interface)

            # Get interface stats
            stats = get_interface_stats(interface)
            if stats:
                rx_mbps, tx_mbps = calculate_bandwidth(interface, stats)

                if rx_mbps is not None:
                    with data_lock:
                        interface_data[interface]['timestamps'].append(current_time)
                        interface_data[interface]['rx_mbps'].append(round(rx_mbps, 2))
                        interface_data[interface]['tx_mbps'].append(round(tx_mbps, 2))
                        interface_data[interface]['current_rx'] = round(rx_mbps, 2)
                        interface_data[interface]['current_tx'] = round(tx_mbps, 2)

            # Get queue stats
            queue_stats = parse_queue_stats(interface)
            if queue_stats:
                queue_rates = calculate_queue_rates(interface, queue_stats)

                if queue_rates:
                    with data_lock:
                        for qos_group, rates in queue_rates.items():
                            if qos_group in interface_data[interface]['queues']:
                                q_data = interface_data[interface]['queues'][qos_group]
                                tx_mbps = round(rates['tx_bps'] / 1_000_000, 2)

                                q_data['tx_pkts'].append(round(rates['tx_pps'], 2))
                                q_data['tx_bytes'].append(tx_mbps)
                                q_data['dropped_pkts'].append(round(rates['drop_pps'], 2))
                                q_data['current_tx_pkts'] = round(rates['tx_pps'], 2)
                                q_data['current_tx_bytes'] = tx_mbps
                                q_data['current_dropped'] = round(rates['drop_pps'], 2)

        time.sleep(1)


# Start monitoring thread
Thread(target=monitor_loop, daemon=True).start()


@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE, qos_colors=QOS_COLORS, switch_ip=SWITCH_IP)


@app.route('/api/interfaces/available')
def get_available_interfaces():
    """Get all available interfaces from switch"""
    interfaces = get_all_interfaces()
    return jsonify(interfaces)


@app.route('/api/interfaces/monitored')
def get_monitored_interfaces():
    """Get list of currently monitored interfaces"""
    with data_lock:
        return jsonify(monitored_interfaces)


@app.route('/api/interfaces/add', methods=['POST'])
def add_interface():
    """Add interface to monitoring"""
    data = request.json
    interface = data.get('interface')

    if not interface:
        return jsonify({'error': 'Interface name required'}), 400

    with data_lock:
        if interface not in monitored_interfaces:
            monitored_interfaces.append(interface)
            init_interface_data(interface)

    return jsonify({'success': True})


@app.route('/api/interfaces/remove', methods=['POST'])
def remove_interface():
    """Remove interface from monitoring"""
    data = request.json
    interface = data.get('interface')

    if not interface:
        return jsonify({'error': 'Interface name required'}), 400

    with data_lock:
        if interface in monitored_interfaces:
            monitored_interfaces.remove(interface)
            if interface in interface_data:
                del interface_data[interface]

    return jsonify({'success': True})


@app.route('/api/data')
def get_data():
    """Get current data for all monitored interfaces"""
    with data_lock:
        result = {}
        for iface in monitored_interfaces:
            if iface not in interface_data:
                continue

            data = interface_data[iface]
            result[iface] = {
                'timestamps': list(data['timestamps']),
                'rx_mbps': list(data['rx_mbps']),
                'tx_mbps': list(data['tx_mbps']),
                'current_rx': data['current_rx'],
                'current_tx': data['current_tx'],
                'queues': {}
            }

            for qos_group, q_data in data['queues'].items():
                result[iface]['queues'][qos_group] = {
                    'tx_pkts': list(q_data['tx_pkts']),
                    'tx_bytes': list(q_data['tx_bytes']),
                    'dropped_pkts': list(q_data['dropped_pkts']),
                    'current_tx_pkts': q_data['current_tx_pkts'],
                    'current_tx_bytes': q_data['current_tx_bytes'],
                    'current_dropped': q_data['current_dropped']
                }

        return result


HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Nexus Network Monitor</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: #0a0e27;
            color: #fff;
            padding: 20px;
        }
        .header {
            background: linear-gradient(90deg, #1e3c72 0%, #2a5298 100%);
            padding: 15px 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        h1 { font-size: 24px; }
        .add-interface {
            background: #1a1f3a;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .add-interface h2 {
            color: #4a9eff;
            margin-bottom: 15px;
            font-size: 18px;
        }
        .interface-selector {
            display: flex;
            gap: 10px;
            align-items: center;
        }
        select, button {
            padding: 10px 15px;
            border-radius: 5px;
            border: 1px solid #3a4a6b;
            background: #0f1626;
            color: #fff;
            font-size: 14px;
        }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border: none;
            cursor: pointer;
            font-weight: bold;
        }
        button:hover { transform: translateY(-2px); }
        button.remove { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
        .monitored-list {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
            margin-top: 15px;
        }
        .monitored-item {
            background: #0f1626;
            padding: 8px 12px;
            border-radius: 5px;
            display: flex;
            align-items: center;
            gap: 10px;
            border-left: 3px solid #10b981;
        }
        .interface-section {
            margin-bottom: 30px;
        }
        .interface-title {
            font-size: 20px;
            font-weight: bold;
            color: #4a9eff;
            margin-bottom: 15px;
            padding: 10px;
            background: #1a1f3a;
            border-radius: 8px;
        }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 20px;
        }
        .card {
            background: #1a1f3a;
            border-radius: 8px;
            padding: 20px;
            border: 1px solid #2a3f5f;
        }
        .card-header {
            font-size: 16px;
            font-weight: bold;
            margin-bottom: 10px;
            color: #8b92a8;
        }
        .stats {
            display: flex;
            gap: 15px;
            margin-bottom: 10px;
            font-size: 13px;
        }
        .stat-value {
            font-size: 18px;
            font-weight: bold;
        }
        .chart-container {
            height: 200px;
            margin-top: 15px;
        }
        .queue-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 15px;
        }
        .queue-card {
            background: #0f1626;
            padding: 15px;
            border-radius: 6px;
            border-left: 4px solid;
        }
        .queue-stats {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 10px;
            font-size: 12px;
            margin-top: 10px;
        }
        .queue-stat {
            text-align: center;
        }
        .queue-stat-label {
            color: #6b7280;
            font-size: 10px;
        }
        .queue-stat-value {
            font-size: 16px;
            font-weight: bold;
            margin-top: 3px;
        }
        .live-indicator {
            background: #10b981;
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 13px;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.6; }
        }
        .no-interfaces {
            text-align: center;
            padding: 60px 20px;
            color: #6b7280;
            font-size: 16px;
        }
    </style>
</head>
<body>
    <div class="header">
        <div>
            <h1>📊 Nexus Network Monitor</h1>
            <div style="opacity: 0.8; font-size: 14px; margin-top: 5px;">Switch: {{ switch_ip }}</div>
        </div>
        <div class="live-indicator">● LIVE</div>
    </div>

    <div class="add-interface">
        <h2>➕ Add Interface to Monitor</h2>
        <div class="interface-selector">
            <select id="interfaceSelect" style="flex: 1;">
                <option value="">Loading interfaces...</option>
            </select>
            <button onclick="addInterface()">Add Interface</button>
        </div>
        <div class="monitored-list" id="monitoredList"></div>
    </div>

    <div id="content"></div>

    <script>
        const QOS_COLORS = ''' + json.dumps(QOS_COLORS) + ''';
        const bandwidthCharts = {};
        const queueCharts = {};
        let monitoredInterfaces = [];

        // Load available interfaces
        async function loadAvailableInterfaces() {
            const response = await fetch('/api/interfaces/available');
            const interfaces = await response.json();

            const select = document.getElementById('interfaceSelect');
            select.innerHTML = '<option value="">-- Select Interface --</option>';

            interfaces.forEach(iface => {
                const option = document.createElement('option');
                option.value = iface.name;
                option.textContent = `${iface.name} (${iface.state})`;
                select.appendChild(option);
            });
        }

        // Load monitored interfaces
        async function loadMonitoredInterfaces() {
            const response = await fetch('/api/interfaces/monitored');
            monitoredInterfaces = await response.json();
            updateMonitoredList();
        }

        // Update monitored interfaces list
        function updateMonitoredList() {
            const list = document.getElementById('monitoredList');

            if (monitoredInterfaces.length === 0) {
                list.innerHTML = '<div style="color: #6b7280; padding: 10px;">No interfaces monitored yet. Select one above to start.</div>';
                return;
            }

            list.innerHTML = monitoredInterfaces.map(iface => `
                <div class="monitored-item">
                    <span>${iface}</span>
                    <button class="remove" style="padding: 5px 10px; font-size: 12px;" onclick="removeInterface('${iface}')">✕</button>
                </div>
            `).join('');
        }

        // Add interface
        async function addInterface() {
            const select = document.getElementById('interfaceSelect');
            const interface = select.value;

            if (!interface) {
                alert('Please select an interface');
                return;
            }

            await fetch('/api/interfaces/add', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ interface })
            });

            await loadMonitoredInterfaces();
            select.value = '';
        }

        // Remove interface
        async function removeInterface(interface) {
            if (!confirm(`Remove ${interface} from monitoring?`)) return;

            await fetch('/api/interfaces/remove', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ interface })
            });

            await loadMonitoredInterfaces();
        }

        // Update dashboard (same as before, but uses monitoredInterfaces dynamically)
        function updateDashboard() {
            fetch('/api/data')
                .then(r => r.json())
                .then(data => {
                    const content = document.getElementById('content');

                    if (Object.keys(data).length === 0) {
                        content.innerHTML = '<div class="no-interfaces"><h2>📡 No Interfaces Monitored</h2><p>Add interfaces above to start monitoring</p></div>';
                        return;
                    }

                    let html = '';
                    Object.keys(data).forEach(iface => {
                        const ifaceData = data[iface];

                        html += `
                            <div class="interface-section">
                                <div class="interface-title">${iface}</div>
                                <div class="grid">
                                    <div class="card">
                                        <div class="card-header">Bandwidth</div>
                                        <div class="stats">
                                            <div>RX: <span class="stat-value" style="color: #10b981;" id="rx-${iface}">0.00 Mbps</span></div>
                                            <div>TX: <span class="stat-value" style="color: #f59e0b;" id="tx-${iface}">0.00 Mbps</span></div>
                                        </div>
                                        <div class="chart-container">
                                            <canvas id="bw-${iface}"></canvas>
                                        </div>
                                    </div>
                                    <div class="card">
                                        <div class="card-header">QoS Queue Traffic (Mbps)</div>
                                        <div class="chart-container">
                                            <canvas id="queue-${iface}"></canvas>
                                        </div>
                                    </div>
                                </div>
                                <div class="queue-grid" id="queue-stats-${iface}"></div>
                            </div>
                        `;
                    });

                    if (content.innerHTML === '') {
                        content.innerHTML = html;
                        Object.keys(data).forEach(iface => {
                            createBandwidthChart(iface);
                            createQueueChart(iface);
                        });
                    }

                    // Update data
                    Object.keys(data).forEach(iface => {
                        const ifaceData = data[iface];

                        // Update bandwidth text
                        const rxElem = document.getElementById(`rx-${iface}`);
                        const txElem = document.getElementById(`tx-${iface}`);
                        if (rxElem) rxElem.textContent = `${ifaceData.current_rx.toFixed(2)} Mbps`;
                        if (txElem) txElem.textContent = `${ifaceData.current_tx.toFixed(2)} Mbps`;

                        // Update charts
                        if (bandwidthCharts[iface]) {
                            bandwidthCharts[iface].data.labels = ifaceData.timestamps;
                            bandwidthCharts[iface].data.datasets[0].data = ifaceData.rx_mbps;
                            bandwidthCharts[iface].data.datasets[1].data = ifaceData.tx_mbps;
                            bandwidthCharts[iface].update('none');
                        }

                        if (queueCharts[iface] && ifaceData.queues) {
                            queueCharts[iface].data.labels = ifaceData.timestamps;
                            let datasetIndex = 0;
                            Object.keys(QOS_COLORS).forEach(qos => {
                                if (ifaceData.queues[qos]) {
                                    queueCharts[iface].data.datasets[datasetIndex].data = ifaceData.queues[qos].tx_bytes;
                                    datasetIndex++;
                                }
                            });
                            queueCharts[iface].update('none');
                        }

                        updateQueueStats(iface, ifaceData.queues);
                    });
                });
        }

        function createBandwidthChart(iface) {
            const ctx = document.getElementById(`bw-${iface}`).getContext('2d');
            bandwidthCharts[iface] = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: [],
                    datasets: [
                        {
                            label: 'RX',
                            data: [],
                            borderColor: '#10b981',
                            backgroundColor: 'rgba(16, 185, 129, 0.1)',
                            tension: 0.3,
                            fill: true,
                            pointRadius: 0
                        },
                        {
                            label: 'TX',
                            data: [],
                            borderColor: '#f59e0b',
                            backgroundColor: 'rgba(245, 158, 11, 0.1)',
                            tension: 0.3,
                            fill: true,
                            pointRadius: 0
                        }
                    ]
                },
                options: chartOptions('Mbps')
            });
        }

        function createQueueChart(iface) {
            const ctx = document.getElementById(`queue-${iface}`).getContext('2d');
            const datasets = [];

            Object.entries(QOS_COLORS).forEach(([qos, config]) => {
                datasets.push({
                    label: config.name,
                    data: [],
                    borderColor: config.color,
                    backgroundColor: config.color + '33',
                    tension: 0.3,
                    fill: false,
                    pointRadius: 0
                });
            });

            queueCharts[iface] = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: [],
                    datasets: datasets
                },
                options: chartOptions('Mbps')
            });
        }

        function updateQueueStats(iface, queues) {
            const container = document.getElementById(`queue-stats-${iface}`);
            if (!container || !queues) return;

            let html = '';
            Object.entries(queues).forEach(([qos, stats]) => {
                const color = QOS_COLORS[qos]?.color || '#6b7280';
                const name = QOS_COLORS[qos]?.name || qos;

                html += `
                    <div class="queue-card" style="border-left-color: ${color};">
                        <div style="font-weight: bold; margin-bottom: 8px;">${name}</div>
                        <div class="queue-stats">
                            <div class="queue-stat">
                                <div class="queue-stat-label">TX Packets/s</div>
                                <div class="queue-stat-value" style="color: ${color};">${stats.current_tx_pkts.toFixed(0)}</div>
                            </div>
                            <div class="queue-stat">
                                <div class="queue-stat-label">TX Mbps</div>
                                <div class="queue-stat-value" style="color: ${color};">${stats.current_tx_bytes.toFixed(2)}</div>
                            </div>
                            <div class="queue-stat">
                                <div class="queue-stat-label">Drops/s</div>
                                <div class="queue-stat-value" style="color: #ef4444;">${stats.current_dropped.toFixed(0)}</div>
                            </div>
                        </div>
                    </div>
                `;
            });

            container.innerHTML = html;
        }

        function chartOptions(yLabel) {
            return {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        labels: { color: '#fff', font: { size: 10 } }
                    }
                },
                scales: {
                    x: {
                        ticks: { color: '#8b92a8', maxTicksLimit: 8, font: { size: 10 } },
                        grid: { color: '#2a3f5f' }
                    },
                    y: {
                        ticks: { color: '#8b92a8', font: { size: 10 } },
                        grid: { color: '#2a3f5f' },
                        beginAtZero: true,
                        title: { display: true, text: yLabel, color: '#8b92a8' }
                    }
                },
                animation: false
            };
        }

        // Initialize
        loadAvailableInterfaces();
        loadMonitoredInterfaces();
        updateDashboard();
        setInterval(updateDashboard, 1000);
        setInterval(loadMonitoredInterfaces, 5000); // Refresh monitored list every 5s
    </script>
</body>
</html>
'''

if __name__ == '__main__':
    print("\n" + "=" * 60)
    print("  NEXUS NETWORK MONITOR - DYNAMIC INTERFACE SELECTION")
    print("=" * 60)
    print(f"\n  Switch: {SWITCH_IP}")
    print(f"\n  Dashboard: http://localhost:5000")
    print("\n  Add/remove interfaces from the web UI!")
    print("\n  Press Ctrl+C to stop\n")
    print("=" * 60 + "\n")

    app.run(host='0.0.0.0', port=5000, debug=False)
