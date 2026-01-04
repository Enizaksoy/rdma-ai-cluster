#!/bin/bash
################################################################################
# RDMA Exporter Installation Script - For ALL 8 RDMA Servers
# This installs the custom RDMA metrics exporter (port 9101)
# Collects: RDMA stats, PFC pause frames, ECN metrics, CNP packets
# Run this script on EACH of the 8 servers
################################################################################

set -e

echo "============================================================"
echo "Installing RDMA Exporter on $(hostname)"
echo "============================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

INSTALL_DIR="/opt/rdma_exporter"
RDMA_USER="rdma_exporter"

echo ""
echo "[1/5] Installing dependencies..."
apt-get update -qq
apt-get install -y python3 python3-pip rdma-core
echo "  ✓ Dependencies installed"

echo ""
echo "[2/5] Creating rdma_exporter user..."
if ! id "$RDMA_USER" &>/dev/null; then
    useradd --no-create-home --shell /bin/false $RDMA_USER
    echo "  ✓ User created"
else
    echo "  ✓ User already exists"
fi

echo ""
echo "[3/5] Installing RDMA exporter..."
mkdir -p $INSTALL_DIR

# Copy the rdma_exporter.py script (must be present in current directory)
if [ -f "rdma_exporter.py" ]; then
    cp rdma_exporter.py $INSTALL_DIR/
    chmod +x $INSTALL_DIR/rdma_exporter.py
    chown -R $RDMA_USER:$RDMA_USER $INSTALL_DIR
    echo "  ✓ RDMA exporter installed to $INSTALL_DIR"
else
    echo "  ✗ ERROR: rdma_exporter.py not found in current directory!"
    echo "  Please copy rdma_exporter.py to the same directory as this script"
    exit 1
fi

echo ""
echo "[4/5] Creating systemd service..."
cat > /etc/systemd/system/rdma_exporter.service <<EOF
[Unit]
Description=RDMA Metrics Exporter for Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/bin/python3 $INSTALL_DIR/rdma_exporter.py

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "  ✓ Service created"

echo ""
echo "[5/5] Starting RDMA Exporter..."
systemctl enable rdma_exporter
systemctl start rdma_exporter
echo "  ✓ RDMA Exporter started"

# Wait and check status
sleep 2
if systemctl is-active --quiet rdma_exporter; then
    echo "  ✓ RDMA Exporter is running"
else
    echo "  ✗ RDMA Exporter failed to start"
    echo "  Check logs: sudo journalctl -u rdma_exporter -f"
    exit 1
fi

echo ""
echo "============================================================"
echo "✓ RDMA Exporter installation complete on $(hostname)!"
echo "============================================================"
echo ""
echo "RDMA Exporter is now running on port 9101"
echo ""
echo "Test locally:"
echo "  curl http://localhost:9101/metrics | grep rdma"
echo ""
echo "Check status:"
echo "  sudo systemctl status rdma_exporter"
echo "  sudo journalctl -u rdma_exporter -f"
echo ""
echo "Metrics endpoint:"
echo "  http://$(hostname -I | awk '{print $1}'):9101/metrics"
echo ""
echo "Collected metrics:"
echo "  - rdma_ecn_marked_packets (ECN-marked RoCE packets)"
echo "  - rdma_cnp_sent (CNP packets sent)"
echo "  - rdma_cnp_handled (CNP packets handled)"
echo "  - rdma_operations (RDMA read/write operations)"
echo "  - pfc_pause_frames (PFC pause frames per priority)"
echo "  - network_bytes/packets (Network statistics)"
echo "============================================================"
