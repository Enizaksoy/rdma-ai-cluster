#!/bin/bash
################################################################################
# Grafana Installation Script for ubunturdma1 (192.168.11.152)
# This installs Grafana for visualizing RDMA metrics from Prometheus
################################################################################

set -e

echo "============================================================"
echo "Installing Grafana on ubunturdma1 (Monitoring Server)"
echo "============================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo ""
echo "[1/5] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq apt-transport-https software-properties-common wget
echo "  ✓ Dependencies installed"

echo ""
echo "[2/5] Adding Grafana GPG key and repository..."
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
echo "  ✓ Repository added"

echo ""
echo "[3/5] Installing Grafana..."
apt-get update -qq
apt-get install -y grafana
echo "  ✓ Grafana installed"

echo ""
echo "[4/5] Configuring Grafana..."
# Configure Grafana to listen on all interfaces
sed -i 's/;http_addr =/http_addr = 0.0.0.0/' /etc/grafana/grafana.ini
sed -i 's/;http_port = 3000/http_port = 3000/' /etc/grafana/grafana.ini

# Set admin password (change this after first login!)
sed -i 's/;admin_password = admin/admin_password = Versa@123!!/' /etc/grafana/grafana.ini

# Configure Prometheus datasource
mkdir -p /etc/grafana/provisioning/datasources
cat > /etc/grafana/provisioning/datasources/prometheus.yml <<'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
EOF

echo "  ✓ Configuration complete"

echo ""
echo "[5/5] Starting Grafana..."
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server
echo "  ✓ Grafana started"

# Wait for Grafana to start
echo ""
echo "Waiting for Grafana to start..."
sleep 5

# Check status
if systemctl is-active --quiet grafana-server; then
    echo "  ✓ Grafana is running"
else
    echo "  ✗ Grafana failed to start"
    echo "  Check logs: sudo journalctl -u grafana-server -f"
    exit 1
fi

echo ""
echo "============================================================"
echo "✓ Grafana installation complete!"
echo "============================================================"
echo ""
echo "Access Grafana:"
echo "  URL:      http://192.168.11.152:3000"
echo "  Username: admin"
echo "  Password: Versa@123!!"
echo ""
echo "IMPORTANT: Change the admin password after first login!"
echo ""
echo "Next steps:"
echo "  1. Open http://192.168.11.152:3000 in your browser"
echo "  2. Login with admin / Versa@123!!"
echo "  3. Import RDMA dashboard (dashboard JSON will be provided)"
echo "  4. Check status: sudo systemctl status grafana-server"
echo "  5. View logs:    sudo journalctl -u grafana-server -f"
echo ""
echo "Prometheus datasource is already configured!"
echo "============================================================"
