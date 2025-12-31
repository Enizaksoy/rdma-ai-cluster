#!/usr/bin/env python3
"""
Simple Nexus Network Monitor - Like Windows Network Monitor
Real-time bandwidth graphs
"""

from flask import Flask, render_template_string
import requests
import json
from collections import deque
from threading import Thread, Lock
import time
from urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

app = Flask(__name__)

# Config
SWITCH_IP = "192.168.50.229"
USERNAME = "admin"
PASSWORD = "<PASSWORD>"
INTERFACES = [
    "Ethernet1/1/1",
    "Ethernet1/1/2",
    "Ethernet1/1/3",
    "Ethernet1/1/4",
    "Ethernet1/2/1",
    "Ethernet1/2/2",
    "Ethernet1/2/3",
    "Ethernet1/2/4"
]

# Data storage
data_lock = Lock()
interface_data = {}
for iface in INTERFACES:
    interface_data[iface] = {
        'timestamps': deque(maxlen=120),  # 2 minutes
        'rx_mbps': deque(maxlen=120),
        'tx_mbps': deque(maxlen=120),
        'current_rx': 0,
        'current_tx': 0
    }

previous_stats = {}


def send_nxapi_command(command):
    """Send command to Nexus switch"""
    url = f"https://{SWITCH_IP}/ins"
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
            data=json.dumps(payload),
            headers={'content-type': 'application/json'},
            auth=(USERNAME, PASSWORD),
            verify=False,
            timeout=5
        )
        return response.json()
    except:
        return None


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


def monitor_loop():
    """Background monitoring thread"""
    while True:
        current_time = time.strftime('%H:%M:%S')

        for interface in INTERFACES:
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

        time.sleep(1)


# Start monitoring
Thread(target=monitor_loop, daemon=True).start()


@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE)


@app.route('/api/data')
def get_data():
    """Get current data for all interfaces"""
    with data_lock:
        return {
            iface: {
                'timestamps': list(data['timestamps']),
                'rx_mbps': list(data['rx_mbps']),
                'tx_mbps': list(data['tx_mbps']),
                'current_rx': data['current_rx'],
                'current_tx': data['current_tx']
            }
            for iface, data in interface_data.items()
        }


HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Nexus Network Monitor</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: #0a0e27;
            color: #fff;
            margin: 0;
            padding: 20px;
        }
        .header {
            background: linear-gradient(90deg, #1e3c72 0%, #2a5298 100%);
            padding: 15px 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        h1 { margin: 0; font-size: 24px; }
        .info { opacity: 0.8; font-size: 14px; margin-top: 5px; }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));
            gap: 20px;
        }
        .card {
            background: #1a1f3a;
            border-radius: 8px;
            padding: 20px;
            border: 1px solid #2a3f5f;
        }
        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }
        .card-title {
            font-size: 18px;
            font-weight: bold;
            color: #4a9eff;
        }
        .stats {
            display: flex;
            gap: 20px;
            font-size: 14px;
        }
        .stat {
            display: flex;
            flex-direction: column;
        }
        .stat-label { color: #8b92a8; font-size: 12px; }
        .stat-value { font-size: 20px; font-weight: bold; }
        .rx { color: #10b981; }
        .tx { color: #f59e0b; }
        .chart-container {
            height: 250px;
            margin-top: 15px;
        }
        .live-indicator {
            position: fixed;
            top: 20px;
            right: 20px;
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
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 Nexus Network Monitor</h1>
        <div class="info">Switch: {{ SWITCH_IP }} | Refresh: 1 second</div>
    </div>

    <div class="live-indicator">● LIVE</div>

    <div class="grid" id="grid"></div>

    <script>
        const INTERFACES = ''' + json.dumps(INTERFACES) + ''';
        const charts = {};

        function updateDashboard() {
            fetch('/api/data')
                .then(r => r.json())
                .then(data => {
                    const grid = document.getElementById('grid');

                    // Create cards if not exist
                    if (grid.children.length === 0) {
                        INTERFACES.forEach(iface => {
                            const card = document.createElement('div');
                            card.className = 'card';
                            card.innerHTML = `
                                <div class="card-header">
                                    <div class="card-title">${iface}</div>
                                    <div class="stats">
                                        <div class="stat">
                                            <span class="stat-label">RX</span>
                                            <span class="stat-value rx" id="rx-${iface}">0 Mbps</span>
                                        </div>
                                        <div class="stat">
                                            <span class="stat-label">TX</span>
                                            <span class="stat-value tx" id="tx-${iface}">0 Mbps</span>
                                        </div>
                                    </div>
                                </div>
                                <div class="chart-container">
                                    <canvas id="chart-${iface}"></canvas>
                                </div>
                            `;
                            grid.appendChild(card);

                            // Create chart
                            const ctx = document.getElementById(`chart-${iface}`).getContext('2d');
                            charts[iface] = new Chart(ctx, {
                                type: 'line',
                                data: {
                                    labels: [],
                                    datasets: [
                                        {
                                            label: 'RX (Mbps)',
                                            data: [],
                                            borderColor: '#10b981',
                                            backgroundColor: 'rgba(16, 185, 129, 0.1)',
                                            tension: 0.3,
                                            fill: true,
                                            pointRadius: 0
                                        },
                                        {
                                            label: 'TX (Mbps)',
                                            data: [],
                                            borderColor: '#f59e0b',
                                            backgroundColor: 'rgba(245, 158, 11, 0.1)',
                                            tension: 0.3,
                                            fill: true,
                                            pointRadius: 0
                                        }
                                    ]
                                },
                                options: {
                                    responsive: true,
                                    maintainAspectRatio: false,
                                    plugins: {
                                        legend: {
                                            labels: { color: '#fff', font: { size: 11 } }
                                        }
                                    },
                                    scales: {
                                        x: {
                                            ticks: {
                                                color: '#8b92a8',
                                                maxTicksLimit: 10
                                            },
                                            grid: { color: '#2a3f5f' }
                                        },
                                        y: {
                                            ticks: { color: '#8b92a8' },
                                            grid: { color: '#2a3f5f' },
                                            beginAtZero: true
                                        }
                                    },
                                    animation: false
                                }
                            });
                        });
                    }

                    // Update data
                    INTERFACES.forEach(iface => {
                        const ifaceData = data[iface];
                        if (ifaceData) {
                            // Update stats
                            document.getElementById(`rx-${iface}`).textContent =
                                `${ifaceData.current_rx.toFixed(2)} Mbps`;
                            document.getElementById(`tx-${iface}`).textContent =
                                `${ifaceData.current_tx.toFixed(2)} Mbps`;

                            // Update chart
                            if (charts[iface]) {
                                charts[iface].data.labels = ifaceData.timestamps;
                                charts[iface].data.datasets[0].data = ifaceData.rx_mbps;
                                charts[iface].data.datasets[1].data = ifaceData.tx_mbps;
                                charts[iface].update('none');
                            }
                        }
                    });
                });
        }

        // Update every 1 second
        updateDashboard();
        setInterval(updateDashboard, 1000);
    </script>
</body>
</html>
'''

if __name__ == '__main__':
    print("\n" + "=" * 60)
    print("  NEXUS NETWORK MONITOR")
    print("=" * 60)
    print(f"\n  Switch: {SWITCH_IP}")
    print(f"  Monitoring {len(INTERFACES)} interfaces")
    print(f"\n  Dashboard: http://localhost:5000")
    print("\n  Press Ctrl+C to stop\n")
    print("=" * 60 + "\n")

    app.run(host='0.0.0.0', port=5000, debug=False)
