#!/bin/bash
################################################################################
# Node Exporter Installation Script - For ALL 8 RDMA Servers
# This collects system metrics (CPU, memory, network, disk)
# Run this script on EACH of the 8 servers
################################################################################

set -e

echo "============================================================"
echo "Installing Node Exporter on $(hostname)"
echo "============================================================"

# Variables
NODE_EXPORTER_VERSION="1.8.2"
NODE_EXPORTER_USER="node_exporter"
INSTALL_DIR="/opt/node_exporter"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo ""
echo "[1/5] Creating node_exporter user..."
if ! id "$NODE_EXPORTER_USER" &>/dev/null; then
    useradd --no-create-home --shell /bin/false $NODE_EXPORTER_USER
    echo "  ✓ User created"
else
    echo "  ✓ User already exists"
fi

echo ""
echo "[2/5] Downloading Node Exporter v${NODE_EXPORTER_VERSION}..."
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
echo "  ✓ Downloaded"

echo ""
echo "[3/5] Extracting and installing..."
tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
mkdir -p $INSTALL_DIR
cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter $INSTALL_DIR/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*
chown -R $NODE_EXPORTER_USER:$NODE_EXPORTER_USER $INSTALL_DIR
echo "  ✓ Installed to $INSTALL_DIR"

echo ""
echo "[4/5] Creating systemd service..."
cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/opt/node_exporter/node_exporter \
  --web.listen-address=0.0.0.0:9100 \
  --collector.netclass \
  --collector.netdev \
  --collector.netstat \
  --collector.ethtool

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "  ✓ Service created"

echo ""
echo "[5/5] Starting Node Exporter..."
systemctl enable node_exporter
systemctl start node_exporter
echo "  ✓ Node Exporter started"

# Wait and check status
sleep 2
if systemctl is-active --quiet node_exporter; then
    echo "  ✓ Node Exporter is running"
else
    echo "  ✗ Node Exporter failed to start"
    echo "  Check logs: sudo journalctl -u node_exporter -f"
    exit 1
fi

echo ""
echo "============================================================"
echo "✓ Node Exporter installation complete on $(hostname)!"
echo "============================================================"
echo ""
echo "Node Exporter is now running on port 9100"
echo ""
echo "Test locally:"
echo "  curl http://localhost:9100/metrics | head -20"
echo ""
echo "Check status:"
echo "  sudo systemctl status node_exporter"
echo "  sudo journalctl -u node_exporter -f"
echo ""
echo "Metrics endpoint:"
echo "  http://$(hostname -I | awk '{print $1}'):9100/metrics"
echo "============================================================"
