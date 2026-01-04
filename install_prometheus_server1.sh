#!/bin/bash
################################################################################
# Prometheus Installation Script for ubunturdma1 (192.168.11.152)
# This installs Prometheus for monitoring all 8 RDMA servers
################################################################################

set -e

echo "============================================================"
echo "Installing Prometheus on ubunturdma1 (Monitoring Server)"
echo "============================================================"

# Variables
PROMETHEUS_VERSION="3.1.0"
PROMETHEUS_USER="prometheus"
PROMETHEUS_DIR="/opt/prometheus"
DATA_DIR="/var/lib/prometheus"
CONFIG_DIR="/etc/prometheus"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo ""
echo "[1/6] Creating Prometheus user..."
if ! id "$PROMETHEUS_USER" &>/dev/null; then
    useradd --no-create-home --shell /bin/false $PROMETHEUS_USER
    echo "  ✓ User created"
else
    echo "  ✓ User already exists"
fi

echo ""
echo "[2/6] Downloading Prometheus v${PROMETHEUS_VERSION}..."
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
echo "  ✓ Downloaded"

echo ""
echo "[3/6] Extracting and installing..."
tar xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
mkdir -p $PROMETHEUS_DIR $DATA_DIR $CONFIG_DIR
cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus $PROMETHEUS_DIR/
cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool $PROMETHEUS_DIR/
cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles $CONFIG_DIR/
cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries $CONFIG_DIR/
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64*
echo "  ✓ Installed to $PROMETHEUS_DIR"

echo ""
echo "[4/6] Setting permissions..."
chown -R $PROMETHEUS_USER:$PROMETHEUS_USER $PROMETHEUS_DIR $DATA_DIR $CONFIG_DIR
echo "  ✓ Permissions set"

echo ""
echo "[5/6] Creating systemd service..."
cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --storage.tsdb.retention.time=30d

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "  ✓ Service created"

echo ""
echo "[6/6] Creating basic configuration..."
cat > $CONFIG_DIR/prometheus.yml <<'EOF'
# Prometheus configuration for RDMA cluster monitoring
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'rdma-ai-cluster'
    datacenter: 'main'

# Alertmanager configuration (optional)
# alerting:
#   alertmanagers:
#     - static_configs:
#         - targets: ['localhost:9093']

# Scrape configurations
scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'prometheus-server'

  # Node Exporter - System metrics for all 8 servers
  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - '192.168.11.152:9100'  # ubunturdma1
        - '192.168.11.153:9100'  # ubunturdma2
        - '192.168.11.154:9100'  # ubunturdma3
        - '192.168.11.155:9100'  # ubunturdma4
        - '192.168.11.107:9100'  # ubunturdma5
        - '192.168.12.51:9100'   # ubunturdma6
        - '192.168.20.150:9100'  # ubunturdma7
        - '192.168.30.94:9100'   # ubunturdma8
        labels:
          cluster: 'rdma-ai-cluster'

  # RDMA Exporter - Custom RDMA/PFC/ECN metrics
  - job_name: 'rdma-exporter'
    static_configs:
      - targets:
        - '192.168.11.152:9101'  # ubunturdma1
        - '192.168.11.153:9101'  # ubunturdma2
        - '192.168.11.154:9101'  # ubunturdma3
        - '192.168.11.155:9101'  # ubunturdma4
        - '192.168.11.107:9101'  # ubunturdma5
        - '192.168.12.51:9101'   # ubunturdma6
        - '192.168.20.150:9101'  # ubunturdma7
        - '192.168.30.94:9101'   # ubunturdma8
        labels:
          cluster: 'rdma-ai-cluster'
EOF

chown $PROMETHEUS_USER:$PROMETHEUS_USER $CONFIG_DIR/prometheus.yml
echo "  ✓ Configuration created"

echo ""
echo "============================================================"
echo "✓ Prometheus installation complete!"
echo "============================================================"
echo ""
echo "Next steps:"
echo "  1. Start Prometheus:  sudo systemctl start prometheus"
echo "  2. Enable on boot:    sudo systemctl enable prometheus"
echo "  3. Check status:      sudo systemctl status prometheus"
echo "  4. View logs:         sudo journalctl -u prometheus -f"
echo ""
echo "Access Prometheus:"
echo "  URL: http://192.168.11.152:9090"
echo ""
echo "Note: Install node_exporter and rdma_exporter on all servers first!"
echo "============================================================"
