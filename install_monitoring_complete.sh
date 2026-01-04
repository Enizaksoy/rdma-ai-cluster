#!/bin/bash
################################################################################
# Complete Monitoring Stack Installation for ubunturdma1
# Installs: Prometheus + Grafana + Opens Firewall
# Run this ONCE on ubunturdma1 (192.168.11.152)
################################################################################

set -e

echo "============================================================"
echo "COMPLETE MONITORING STACK INSTALLATION"
echo "Installing Prometheus + Grafana on ubunturdma1"
echo "============================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo ""
echo "Server: $(hostname)"
echo "IP: $(hostname -I | awk '{print $1}')"
echo ""
read -p "Press ENTER to start installation..."

################################################################################
# PART 1: INSTALL PROMETHEUS
################################################################################

echo ""
echo "============================================================"
echo "PART 1: Installing Prometheus"
echo "============================================================"

PROMETHEUS_VERSION="3.1.0"
PROMETHEUS_USER="prometheus"
PROMETHEUS_DIR="/opt/prometheus"
DATA_DIR="/var/lib/prometheus"
CONFIG_DIR="/etc/prometheus"

echo "[1/6] Creating Prometheus user..."
if ! id "$PROMETHEUS_USER" &>/dev/null; then
    useradd --no-create-home --shell /bin/false $PROMETHEUS_USER
    echo "  ✓ User created"
else
    echo "  ✓ User already exists"
fi

echo "[2/6] Downloading Prometheus..."
cd /tmp
if [ ! -f "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" ]; then
    wget -q --show-progress https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
fi
echo "  ✓ Downloaded"

echo "[3/6] Installing Prometheus..."
tar xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
mkdir -p $PROMETHEUS_DIR $DATA_DIR $CONFIG_DIR
cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus $PROMETHEUS_DIR/
cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool $PROMETHEUS_DIR/
cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles $CONFIG_DIR/
cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries $CONFIG_DIR/
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64*
chown -R $PROMETHEUS_USER:$PROMETHEUS_USER $PROMETHEUS_DIR $DATA_DIR $CONFIG_DIR
echo "  ✓ Installed to $PROMETHEUS_DIR"

echo "[4/6] Creating Prometheus configuration..."
cat > $CONFIG_DIR/prometheus.yml <<'EOFPROM'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'rdma-ai-cluster'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - '192.168.11.152:9100'
        - '192.168.11.153:9100'
        - '192.168.11.154:9100'
        - '192.168.11.155:9100'
        - '192.168.11.107:9100'
        - '192.168.12.51:9100'
        - '192.168.20.150:9100'
        - '192.168.30.94:9100'

  - job_name: 'rdma-exporter'
    static_configs:
      - targets:
        - '192.168.11.152:9101'
        - '192.168.11.153:9101'
        - '192.168.11.154:9101'
        - '192.168.11.155:9101'
        - '192.168.11.107:9101'
        - '192.168.12.51:9101'
        - '192.168.20.150:9101'
        - '192.168.30.94:9101'
EOFPROM
chown $PROMETHEUS_USER:$PROMETHEUS_USER $CONFIG_DIR/prometheus.yml
echo "  ✓ Configuration created"

echo "[5/6] Creating systemd service..."
cat > /etc/systemd/system/prometheus.service <<'EOFSVC'
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
EOFSVC
systemctl daemon-reload
echo "  ✓ Service created"

echo "[6/6] Starting Prometheus..."
systemctl enable prometheus
systemctl start prometheus
sleep 3
if systemctl is-active --quiet prometheus; then
    echo "  ✓ Prometheus is running"
else
    echo "  ✗ Prometheus failed to start"
    journalctl -u prometheus -n 20
    exit 1
fi

################################################################################
# PART 2: INSTALL GRAFANA
################################################################################

echo ""
echo "============================================================"
echo "PART 2: Installing Grafana"
echo "============================================================"

echo "[1/5] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq apt-transport-https software-properties-common wget
echo "  ✓ Dependencies installed"

echo "[2/5] Adding Grafana repository..."
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
echo "  ✓ Repository added"

echo "[3/5] Installing Grafana..."
apt-get update -qq
apt-get install -y grafana
echo "  ✓ Grafana installed"

echo "[4/5] Configuring Grafana..."
sed -i 's/;http_addr =/http_addr = 0.0.0.0/' /etc/grafana/grafana.ini
sed -i 's/;http_port = 3000/http_port = 3000/' /etc/grafana/grafana.ini
sed -i 's/;admin_password = admin/admin_password = Versa@123!!/' /etc/grafana/grafana.ini

mkdir -p /etc/grafana/provisioning/datasources
cat > /etc/grafana/provisioning/datasources/prometheus.yml <<'EOFGRAF'
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
EOFGRAF
echo "  ✓ Configuration complete"

echo "[5/5] Starting Grafana..."
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server
sleep 3
if systemctl is-active --quiet grafana-server; then
    echo "  ✓ Grafana is running"
else
    echo "  ✗ Grafana failed to start"
    journalctl -u grafana-server -n 20
    exit 1
fi

################################################################################
# PART 3: OPEN FIREWALL PORTS
################################################################################

echo ""
echo "============================================================"
echo "PART 3: Configuring Firewall"
echo "============================================================"

if command -v ufw &> /dev/null; then
    echo "Configuring UFW firewall..."

    # Allow Prometheus
    ufw allow 9090/tcp comment 'Prometheus'
    echo "  ✓ Port 9090 (Prometheus) allowed"

    # Allow Grafana
    ufw allow 3000/tcp comment 'Grafana'
    echo "  ✓ Port 3000 (Grafana) allowed"

    # Reload UFW
    ufw reload 2>/dev/null || true
    echo "  ✓ Firewall updated"
else
    echo "  ⚠ UFW not installed, skipping firewall configuration"
fi

################################################################################
# PART 4: VERIFICATION
################################################################################

echo ""
echo "============================================================"
echo "PART 4: Verification"
echo "============================================================"

MY_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "Testing Prometheus..."
if curl -s http://localhost:9090/-/ready | grep -q "Prometheus Server is Ready"; then
    echo "  ✓ Prometheus is responding"
else
    echo "  ✗ Prometheus is not responding"
fi

echo ""
echo "Testing Grafana..."
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo "  ✓ Grafana is responding"
else
    echo "  ✗ Grafana is not responding"
fi

echo ""
echo "Checking listening ports..."
netstat -tuln | grep -E ":(9090|3000)" || echo "  ⚠ Ports not listening"

################################################################################
# COMPLETION
################################################################################

echo ""
echo "============================================================"
echo "✅ INSTALLATION COMPLETE!"
echo "============================================================"
echo ""
echo "Access your monitoring stack:"
echo ""
echo "  Prometheus:  http://$MY_IP:9090"
echo "  Grafana:     http://$MY_IP:3000"
echo ""
echo "Grafana Login:"
echo "  Username: admin"
echo "  Password: Versa@123!!"
echo ""
echo "Next steps:"
echo "  1. Open http://$MY_IP:3000 in your browser"
echo "  2. Login with admin / Versa@123!!"
echo "  3. Import dashboard: grafana_rdma_dashboard.json"
echo "  4. Install exporters on all 8 servers"
echo ""
echo "Check status:"
echo "  sudo systemctl status prometheus"
echo "  sudo systemctl status grafana-server"
echo ""
echo "View logs:"
echo "  sudo journalctl -u prometheus -f"
echo "  sudo journalctl -u grafana-server -f"
echo "============================================================"
