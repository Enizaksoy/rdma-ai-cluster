# RDMA Cluster Monitoring Setup Guide
## Prometheus + Grafana + Custom RDMA Exporters

**Date:** January 1, 2026
**Monitoring Server:** ubunturdma1 (192.168.11.152)
**Monitored Servers:** All 8 RDMA servers
**Purpose:** Monitor RDMA traffic, PFC pause frames, ECN packets, CNP packets

---

## 📋 Overview

This guide sets up a complete monitoring solution for your 8-node RDMA cluster:

- **Prometheus** (192.168.11.152:9090) - Metrics collection and storage
- **Grafana** (192.168.11.152:3000) - Visualization dashboards
- **Node Exporter** (all servers:9100) - System metrics
- **RDMA Exporter** (all servers:9101) - Custom RDMA/PFC/ECN metrics

**Metrics Collected:**
- ECN-marked RoCE packets
- CNP packets (sent/received/handled)
- PFC pause frames (per priority)
- RDMA operations (read/write)
- Network throughput and drops
- System resources (CPU, memory, disk)

---

## 🚀 Installation Steps

### Step 1: Install Prometheus on ubunturdma1 (Monitoring Server)

```bash
# SSH to ubunturdma1
ssh versa@192.168.11.152

# Copy the installation script
# (You'll need to transfer install_prometheus_server1.sh to this server)

# Run the installation
sudo bash install_prometheus_server1.sh

# Start Prometheus
sudo systemctl start prometheus
sudo systemctl enable prometheus

# Verify it's running
sudo systemctl status prometheus
curl http://localhost:9090/-/ready
```

**Access Prometheus:** http://192.168.11.152:9090

---

### Step 2: Install Grafana on ubunturdma1 (Monitoring Server)

```bash
# Still on ubunturdma1
# Copy the installation script
# (You'll need to transfer install_grafana_server1.sh to this server)

# Run the installation
sudo bash install_grafana_server1.sh

# Grafana should auto-start
# Verify it's running
sudo systemctl status grafana-server
```

**Access Grafana:**
URL: http://192.168.11.152:3000
Username: `admin`
Password: `Versa@123!!`

**IMPORTANT:** Change the admin password after first login!

---

### Step 3: Install Node Exporter on ALL 8 Servers

Run this on **EACH** of the 8 servers:

```bash
# Server list:
# 192.168.11.152 (ubunturdma1)
# 192.168.11.153 (ubunturdma2)
# 192.168.11.154 (ubunturdma3)
# 192.168.11.155 (ubunturdma4)
# 192.168.11.107 (ubunturdma5)
# 192.168.12.51  (ubunturdma6)
# 192.168.20.150 (ubunturdma7)
# 192.168.30.94  (ubunturdma8)

# On each server:
ssh versa@<server-ip>

# Copy install_node_exporter_all_servers.sh to the server

# Run the installation
sudo bash install_node_exporter_all_servers.sh

# Verify
curl http://localhost:9100/metrics | head -20
```

---

### Step 4: Install RDMA Exporter on ALL 8 Servers

Run this on **EACH** of the 8 servers:

```bash
# On each server:
ssh versa@<server-ip>

# IMPORTANT: Copy BOTH files to the server:
# - install_rdma_exporter_all_servers.sh
# - rdma_exporter.py

# Make sure both files are in the same directory
ls -l install_rdma_exporter_all_servers.sh rdma_exporter.py

# Run the installation
sudo bash install_rdma_exporter_all_servers.sh

# Verify
curl http://localhost:9101/metrics | grep rdma
```

---

### Step 5: Verify Prometheus is Scraping All Targets

```bash
# On ubunturdma1, check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'

# Or open in browser:
# http://192.168.11.152:9090/targets
```

You should see:
- 1 prometheus target (localhost:9090) - **UP**
- 8 node-exporter targets (all servers:9100) - **UP**
- 8 rdma-exporter targets (all servers:9101) - **UP**

**Total: 17 targets, all should be UP**

---

### Step 6: Import Grafana Dashboard

1. Open Grafana: http://192.168.11.152:3000
2. Login with `admin` / `Versa@123!!`
3. Click **+** (Create) → **Import**
4. Click **Upload JSON file**
5. Select `grafana_rdma_dashboard.json`
6. Click **Import**

You should now see the **RDMA Cluster Monitoring - PFC/ECN/CNP** dashboard!

---

## 📊 Dashboard Panels

Your new Grafana dashboard includes:

1. **ECN-Marked RoCE Packets** - Shows ECN marking activity (switch congestion signaling)
2. **CNP Packets** - Congestion Notification Packets (sent vs handled)
3. **PFC Pause Frames (Priority 3)** - RoCE traffic pause frames
4. **RDMA Write Operations** - RDMA write request rates
5. **Network Throughput** - Bytes per second on all interfaces
6. **Total ECN Marked Packets** - Gauge showing cumulative ECN packets
7. **Total CNP Packets Sent** - Gauge showing cumulative CNP packets
8. **Total PFC Pause Frames** - Gauge showing cumulative pause frames
9. **Network Packet Drops** - Should be ZERO or minimal (PFC prevents drops!)

---

## 🔍 Monitoring Your RDMA Traffic

### Check ECN is Working:

```bash
# On any server
curl http://localhost:9101/metrics | grep rdma_ecn

# Should show increasing numbers during training:
rdma_ecn_marked_packets{device="rocep19s0"} 40510552
```

### Check PFC is Working:

```bash
# On any server
curl http://localhost:9101/metrics | grep pfc_pause_frames | grep priority=\"3\"

# Should show increasing pause frames during congestion:
pfc_pause_frames{interface="ens224",priority="3",direction="rx"} 1234567
pfc_pause_frames{interface="ens224",priority="3",direction="tx"} 567890
```

### Check CNP Packets:

```bash
# On any server
curl http://localhost:9101/metrics | grep cnp

# Should show:
rdma_cnp_sent{device="rocep19s0"} 30458349      # Sending CNPs
rdma_cnp_handled{device="rocep19s0"} 1169933    # Handling CNPs (reducing rate)
```

---

## 🎯 What to Look For During AI Training

### ✅ Healthy RDMA Network (PFC/ECN Working):

**In Grafana Dashboard:**
- ECN-marked packets: **Steadily increasing** during training bursts
- CNP sent: **Increases** during congestion (receivers telling senders to slow down)
- CNP handled: **Increases** during congestion (senders reducing transmission rate)
- PFC pause frames: **Increases** during severe congestion (emergency brake)
- Network packet drops: **ZERO or minimal** (< 0.001% drop rate)
- RDMA operations: **Smooth, consistent rate**

**What this means:**
- ECN catches congestion early (50-75% buffer fill)
- CNP signals cause rate reduction (DCQCN algorithm working)
- PFC prevents buffer overflow (95%+ buffer fill)
- Result: **Zero packet loss, lossless RDMA traffic**

### ❌ Unhealthy RDMA Network (PFC/ECN NOT Working):

- ECN-marked packets: **Zero** (ECN not configured)
- CNP packets: **Zero** (no congestion notification)
- PFC pause frames: **Zero** (PFC not enabled)
- Network packet drops: **High and increasing** (millions of drops)
- RDMA operations: **Irregular, with gaps/timeouts**

**What this means:**
- Buffers overflow without warning
- Packets get dropped
- RDMA operations fail and timeout
- Training performance degrades

---

## 🔧 Troubleshooting

### Problem: Prometheus targets show "DOWN"

**Solution:**
```bash
# Check if exporter is running
sudo systemctl status node_exporter
sudo systemctl status rdma_exporter

# Check if port is listening
netstat -tuln | grep 9100  # node_exporter
netstat -tuln | grep 9101  # rdma_exporter

# Check firewall
sudo ufw status
sudo ufw allow 9100/tcp
sudo ufw allow 9101/tcp

# Restart exporters
sudo systemctl restart node_exporter
sudo systemctl restart rdma_exporter
```

### Problem: RDMA metrics show zero

**Solution:**
```bash
# Check RDMA devices are detected
rdma link show

# Check RDMA exporter logs
sudo journalctl -u rdma_exporter -f

# Test RDMA exporter manually
python3 /opt/rdma_exporter/rdma_exporter.py

# Verify RDMA statistics are available
rdma statistic show link rocep19s0/1
```

### Problem: Grafana shows "No Data"

**Solution:**
1. Check Prometheus datasource: Configuration → Data Sources → Prometheus
2. Test the datasource (should show "Data source is working")
3. Check if metrics exist in Prometheus:
   - Go to http://192.168.11.152:9090
   - Execute query: `rdma_ecn_marked_packets`
   - Should show data
4. Check time range in Grafana (top right)

---

## 📈 Advanced: Alerting (Optional)

You can configure Prometheus alerts for critical conditions:

**Example Alert Rules** (add to `/etc/prometheus/prometheus.yml`):

```yaml
rule_files:
  - "alert_rules.yml"
```

Create `/etc/prometheus/alert_rules.yml`:

```yaml
groups:
  - name: rdma_alerts
    interval: 30s
    rules:
      # Alert if packet drops occur
      - alert: RDMAPacketDrops
        expr: rate(network_packets_dropped[1m]) > 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "RDMA packet drops detected on {{ $labels.instance }}"
          description: "Packet drops detected: {{ $value }} packets/sec. PFC may not be working correctly."

      # Alert if ECN is not working
      - alert: NoECNActivity
        expr: rate(rdma_ecn_marked_packets[5m]) == 0
        for: 10m
        labels:
          severity: info
        annotations:
          summary: "No ECN activity on {{ $labels.device }}"
          description: "ECN marking is not occurring. Either no congestion or ECN not configured."

      # Alert if PFC pause frames spike
      - alert: HighPFCPauseActivity
        expr: rate(pfc_pause_frames{priority="3"}[1m]) > 10000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High PFC pause frame rate on {{ $labels.interface }}"
          description: "PFC pause rate: {{ $value }} frames/sec. Severe congestion detected."
```

---

## 📁 Files Created

All files are in: `C:\Users\eniza\Documents\claudechats\`

### Installation Scripts:
- `install_prometheus_server1.sh` - Prometheus installation (ubunturdma1 only)
- `install_grafana_server1.sh` - Grafana installation (ubunturdma1 only)
- `install_node_exporter_all_servers.sh` - Node exporter (run on ALL 8 servers)
- `install_rdma_exporter_all_servers.sh` - RDMA exporter installer (run on ALL 8 servers)

### Exporter Code:
- `rdma_exporter.py` - Custom RDMA metrics exporter (must be copied to all servers)

### Dashboard:
- `grafana_rdma_dashboard.json` - Pre-configured Grafana dashboard

### Documentation:
- `PROMETHEUS_GRAFANA_INSTALLATION_GUIDE.md` - This file

---

## ✅ Quick Installation Checklist

- [ ] Install Prometheus on ubunturdma1
- [ ] Install Grafana on ubunturdma1
- [ ] Install node_exporter on all 8 servers
- [ ] Install rdma_exporter on all 8 servers (with rdma_exporter.py)
- [ ] Verify all Prometheus targets are UP
- [ ] Import Grafana dashboard
- [ ] Change Grafana admin password
- [ ] Run distributed training to generate RDMA traffic
- [ ] Watch the metrics flow in Grafana!

---

## 🎉 Success Criteria

When everything is working, you should see:

1. **Prometheus:** http://192.168.11.152:9090/targets shows 17 targets, all UP
2. **Grafana:** http://192.168.11.152:3000 shows RDMA dashboard with live data
3. **During training:** ECN packets increasing, PFC pause frames active, ZERO drops
4. **Lossless RDMA:** Your AI training runs smoothly without network-related failures

---

**Questions or Issues?**
- Check logs: `sudo journalctl -u prometheus -f`
- Check logs: `sudo journalctl -u grafana-server -f`
- Check logs: `sudo journalctl -u rdma_exporter -f`
- Test endpoints manually: `curl http://localhost:9101/metrics`

**Ready to monitor your RDMA cluster!** 🚀
