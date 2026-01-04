#!/bin/bash
# Fix ESXi Exporter - Install sshpass and restart
# Run this on server 192.168.11.152

echo "=== ESXi Exporter Fix Script ==="
echo ""

echo "1. Installing sshpass..."
sudo apt-get update -qq
sudo apt-get install -y sshpass

echo ""
echo "2. Stopping old exporter..."
pkill -9 -f esxi_stats_exporter.py

echo ""
echo "3. Starting ESXi exporter..."
cd ~
nohup python3 ~/esxi_stats_exporter.py > /tmp/esxi_stats_exporter.log 2>&1 &

echo ""
echo "4. Waiting for startup..."
sleep 5

echo ""
echo "5. Testing metrics collection..."
if curl -s http://localhost:9104/metrics | grep -q "esxi_pause_rx_phy{"; then
    echo "✅ SUCCESS! ESXi exporter is collecting data:"
    curl -s http://localhost:9104/metrics | grep esxi_pause_rx_phy | head -4
    echo ""
    echo "Grafana dashboard will now show ESXi pause frames!"
else
    echo "❌ No data yet. Checking logs..."
    tail -20 /tmp/esxi_stats_exporter.log
fi

echo ""
echo "=== Done ==="
