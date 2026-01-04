#!/bin/bash
# Install Nexus Prometheus Exporter on monitoring server

set -e

echo "=== Installing Nexus Switch Prometheus Exporter ==="

# Install on ubunturdma1 (monitoring server)
MONITORING_SERVER="192.168.11.152"

# Copy exporter to server
scp nexus_prometheus_exporter.py versa@${MONITORING_SERVER}:/tmp/

# Install and configure
ssh versa@${MONITORING_SERVER} << 'EOF'
sudo mkdir -p /opt/nexus_exporter
sudo mv /tmp/nexus_prometheus_exporter.py /opt/nexus_exporter/
sudo chmod +x /opt/nexus_exporter/nexus_prometheus_exporter.py

# Create systemd service
sudo tee /etc/systemd/system/nexus_exporter.service > /dev/null << 'SYSTEMD'
[Unit]
Description=Nexus Switch Prometheus Exporter
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/nexus_exporter
ExecStart=/usr/bin/python3 /opt/nexus_exporter/nexus_prometheus_exporter.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SYSTEMD

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable nexus_exporter
sudo systemctl start nexus_exporter

echo "Nexus exporter installed and started!"
echo "Metrics available at: http://192.168.11.152:9102/metrics"
EOF

# Add to Prometheus configuration
ssh versa@${MONITORING_SERVER} << 'EOF'
# Backup existing config
sudo cp /etc/prometheus/prometheus.yml /etc/prometheus/prometheus.yml.backup

# Add nexus-exporter job
if ! grep -q "job_name: 'nexus-switch'" /etc/prometheus/prometheus.yml; then
    sudo tee -a /etc/prometheus/prometheus.yml > /dev/null << 'PROM'

  # Nexus Switch Metrics
  - job_name: 'nexus-switch'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:9102']
        labels:
          switch: 'nexus-ai-leaf1'
          location: 'lab'
PROM

    sudo systemctl restart prometheus
    echo "Prometheus configuration updated!"
else
    echo "Nexus exporter already in Prometheus config"
fi
EOF

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Nexus Switch Exporter: http://192.168.11.152:9102/metrics"
echo "Prometheus: http://192.168.11.152:9090"
echo "Grafana: http://192.168.11.152:3000"
echo ""
echo "Metrics being collected:"
echo "  - PFC pause frames (RxPPP, TxPPP)"
echo "  - Flow control pause frames"
echo "  - Interface counters (RX/TX bytes, packets)"
echo "  - Queue drops per QoS group"
echo ""
echo "Interfaces monitored:"
echo "  - ethernet1/1/1"
echo "  - ethernet1/1/2"
echo "  - ethernet1/2/1"
echo "  - ethernet1/2/2"
