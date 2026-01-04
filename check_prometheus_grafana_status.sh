#!/bin/bash
################################################################################
# Troubleshooting Script for Prometheus/Grafana
# Run this on ubunturdma1 to check why services aren't accessible
################################################################################

echo "============================================================"
echo "Checking Prometheus and Grafana Status"
echo "============================================================"

echo ""
echo "[1] Checking if Prometheus is installed..."
if [ -f "/opt/prometheus/prometheus" ]; then
    echo "  ✓ Prometheus binary found at /opt/prometheus/prometheus"
else
    echo "  ✗ Prometheus NOT installed"
    echo "  Run: sudo bash install_prometheus_server1.sh"
fi

echo ""
echo "[2] Checking if Prometheus service exists..."
if systemctl list-unit-files | grep -q prometheus.service; then
    echo "  ✓ Prometheus service exists"
    systemctl status prometheus --no-pager | grep "Active:"
else
    echo "  ✗ Prometheus service NOT found"
fi

echo ""
echo "[3] Checking if Prometheus is listening on port 9090..."
if netstat -tuln | grep -q ":9090"; then
    echo "  ✓ Prometheus is listening on port 9090"
    netstat -tuln | grep ":9090"
else
    echo "  ✗ Prometheus is NOT listening on port 9090"
    echo "  Try: sudo systemctl start prometheus"
fi

echo ""
echo "[4] Testing Prometheus locally..."
if curl -s http://localhost:9090/-/ready | grep -q "Prometheus Server is Ready"; then
    echo "  ✓ Prometheus is responding locally"
else
    echo "  ✗ Prometheus is NOT responding"
    echo "  Check logs: sudo journalctl -u prometheus -n 50"
fi

echo ""
echo "[5] Checking if Grafana is installed..."
if [ -f "/usr/sbin/grafana-server" ]; then
    echo "  ✓ Grafana binary found"
else
    echo "  ✗ Grafana NOT installed"
    echo "  Run: sudo bash install_grafana_server1.sh"
fi

echo ""
echo "[6] Checking if Grafana service exists..."
if systemctl list-unit-files | grep -q grafana-server.service; then
    echo "  ✓ Grafana service exists"
    systemctl status grafana-server --no-pager | grep "Active:"
else
    echo "  ✗ Grafana service NOT found"
fi

echo ""
echo "[7] Checking if Grafana is listening on port 3000..."
if netstat -tuln | grep -q ":3000"; then
    echo "  ✓ Grafana is listening on port 3000"
    netstat -tuln | grep ":3000"
else
    echo "  ✗ Grafana is NOT listening on port 3000"
    echo "  Try: sudo systemctl start grafana-server"
fi

echo ""
echo "[8] Checking firewall status..."
if command -v ufw &> /dev/null; then
    ufw_status=$(sudo ufw status | head -1)
    echo "  UFW Status: $ufw_status"

    if sudo ufw status | grep -q "9090.*ALLOW"; then
        echo "  ✓ Port 9090 is allowed in firewall"
    else
        echo "  ✗ Port 9090 may be blocked"
        echo "  Run: sudo ufw allow 9090/tcp"
    fi

    if sudo ufw status | grep -q "3000.*ALLOW"; then
        echo "  ✓ Port 3000 is allowed in firewall"
    else
        echo "  ✗ Port 3000 may be blocked"
        echo "  Run: sudo ufw allow 3000/tcp"
    fi
else
    echo "  UFW not installed (firewall may not be active)"
fi

echo ""
echo "[9] Checking network connectivity..."
MY_IP=$(hostname -I | awk '{print $1}')
echo "  Server IP: $MY_IP"
echo ""
echo "  Test from your Windows machine:"
echo "    curl http://$MY_IP:9090/-/ready"
echo "    curl http://$MY_IP:3000/api/health"

echo ""
echo "============================================================"
echo "Quick Fixes:"
echo "============================================================"
echo ""
echo "If Prometheus is not running:"
echo "  sudo systemctl start prometheus"
echo "  sudo systemctl enable prometheus"
echo ""
echo "If Grafana is not running:"
echo "  sudo systemctl start grafana-server"
echo "  sudo systemctl enable grafana-server"
echo ""
echo "If firewall is blocking:"
echo "  sudo ufw allow 9090/tcp"
echo "  sudo ufw allow 3000/tcp"
echo ""
echo "View logs:"
echo "  sudo journalctl -u prometheus -f"
echo "  sudo journalctl -u grafana-server -f"
echo "============================================================"
