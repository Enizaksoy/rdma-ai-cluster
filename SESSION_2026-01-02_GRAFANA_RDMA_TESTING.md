# Grafana & Prometheus RDMA Traffic Testing Session
**Date:** January 2, 2026
**Purpose:** Review Prometheus/Grafana setup and generate RDMA traffic for monitoring

---

## Session Overview

This session covered:
1. Review of the Prometheus/Grafana installation guide
2. Generating RDMA traffic across all servers
3. Verifying metrics collection
4. Accessing Grafana dashboard

---

## Questions & Answers

### Q: What was the Grafana server IP?
**A:** `192.168.11.152` (ubunturdma1)

**Access URL:** http://192.168.11.152:3000
- Username: `admin`
- Password: `Versa@123!!`

---

### Q: What were the queries?

**Monitoring Queries (Manual Testing):**

```bash
# Check ECN packets
curl http://localhost:9101/metrics | grep rdma_ecn
# Metric: rdma_ecn_marked_packets{device="rocep19s0"}

# Check PFC pause frames
curl http://localhost:9101/metrics | grep pfc_pause_frames | grep priority=\"3\"
# Metrics: pfc_pause_frames{interface="ens224",priority="3",direction="rx"}
#          pfc_pause_frames{interface="ens224",priority="3",direction="tx"}

# Check CNP packets
curl http://localhost:9101/metrics | grep cnp
# Metrics: rdma_cnp_sent{device="rocep19s0"}
#          rdma_cnp_handled{device="rocep19s0"}
```

**PromQL Queries for Grafana:**

```promql
# RDMA Operations Rate
rate(rdma_operations[1m])

# Network Traffic on RDMA Interfaces
rate(network_bytes{interface=~"ens224|ens192"}[1m])

# ECN-Marked Packets
rdma_ecn_marked_packets

# PFC Pause Frames
pfc_pause_frames{priority="3"}

# Packet Drops
rate(network_packets_dropped[1m])
```

**Alert Rules (from documentation):**

```yaml
# Packet drops
rate(network_packets_dropped[1m]) > 0

# No ECN activity
rate(rdma_ecn_marked_packets[5m]) == 0

# High PFC pause activity
rate(pfc_pause_frames{priority="3"}[1m]) > 10000
```

---

## RDMA Traffic Generation Test

### Objective
Generate RDMA traffic across all 8 servers to produce ECN and PFC packets visible in Grafana.

### Server Status
- **192.168.11.152** (ubunturdma1): ✓ Online
- **192.168.11.153** (ubunturdma2): ✓ Online
- **192.168.11.154** (ubunturdma3): ✓ Online
- **192.168.11.155** (ubunturdma4): ✓ Online
- **192.168.11.107** (ubunturdma5): ✓ Online
- **192.168.12.51** (ubunturdma6): ✗ Offline (unreachable)
- **192.168.20.150** (ubunturdma7): ✓ Online
- **192.168.30.94** (ubunturdma8): ✓ Online

**Result:** 7/8 servers online and participating

### SSH Authentication Issue & Resolution

**Problem:** Encountered SSH authentication failures (permission denied)

**Solution:** Created expect script for automated SSH with password authentication:

```bash
cat > /tmp/test_ssh.exp << 'EOF'
#!/usr/bin/expect -f
set ip [lindex $argv 0]
set cmd [lindex $argv 1]
set timeout 10
spawn ssh -o StrictHostKeyChecking=no versa@$ip "$cmd"
expect {
    "password:" {
        send "Versa@123!!\r"
        exp_continue
    }
    eof
}
EOF
chmod +x /tmp/test_ssh.exp
```

**Usage:**
```bash
expect /tmp/test_ssh.exp "192.168.11.152" "hostname"
```

### Traffic Generation Method

**Script Used:** Modified version of `saturate_cross_esxi.sh`

**Traffic Flows:**
1. Started ib_write_bw servers on all 8 hosts
2. Created bidirectional RDMA flows between hosts
3. Duration: 300 seconds (5 minutes)
4. Expected aggregate: ~48 Gbps across switch

**Manually Started Client Connections:**
```bash
# Server 2 -> Server 1
ib_write_bw -d rocep11s0 -D 600 --run_infinitely 192.168.251.111

# Server 3 -> Server 4
ib_write_bw -d rocep19s0 -D 600 --run_infinitely 192.168.250.114

# Server 5 -> Server 2
ib_write_bw -d rocep11s0 -D 600 --run_infinitely 192.168.250.112

# Server 7 -> Server 1
ib_write_bw -d rocep11s0 -D 600 --run_infinitely 192.168.251.111
```

---

## Monitoring Results

### Prometheus Status
- **Targets:** 15/17 UP (2 down - expected due to server 192.168.12.51)
- **URL:** http://192.168.11.152:9090

**Query Test:**
```bash
curl -s "http://192.168.11.152:9090/api/v1/query?query=rdma_operations"
```
✓ Successfully collecting metrics from all online servers

### Grafana Status
- **URL:** http://192.168.11.152:3000
- **Status:** ✓ Running (HTTP 302 redirect to login)
- **Dashboard:** RDMA Cluster Monitoring - PFC/ECN/CNP

### Metrics Collected

**RDMA Operations (Server 192.168.11.152):**
```
rdma_operations{device="rocep19s0",operation="rx_write_requests"} 381104
rdma_operations{device="rocep19s0",operation="rx_read_requests"} 0
```
✓ RDMA traffic confirmed flowing

**Network Traffic (ens224 - RDMA interface):**
```
network_bytes{interface="ens224",direction="rx"} 77572
network_bytes{interface="ens224",direction="tx"} 2402
network_packets{interface="ens224",direction="rx"} 1194
network_packets{interface="ens224",direction="tx"} 17
```

**ECN/PFC Status:**
```
rdma_ecn_marked_packets{interface="ens224",source="ethtool"} 0
rdma_cnp_packets{device="rocep19s0",type="slow_restart"} 0
pfc_pause_frames{interface="ens224",priority="global",direction="rx"} 0
pfc_pause_frames{interface="ens224",priority="global",direction="tx"} 0
```
⚠️ No ECN or PFC packets detected (insufficient congestion)

---

## Key Findings

### ✅ Working Components
1. **Prometheus** - Collecting metrics from 15 targets
2. **Grafana** - Running and accessible
3. **Node Exporter** - System metrics flowing
4. **RDMA Exporter** - Custom metrics being collected
5. **RDMA Traffic** - 381K+ write operations confirmed

### ⚠️ Areas Needing Attention
1. **ECN Packets:** Showing 0 (may need higher congestion or ECN config verification)
2. **PFC Pause Frames:** Showing 0 (may need higher load or PFC verification)
3. **Server 6:** Offline (192.168.12.51)

### Possible Reasons for Zero ECN/PFC
1. Current traffic load insufficient to cause congestion
2. ECN/PFC may not be properly configured on switch
3. Buffer thresholds not being reached
4. Need to saturate multiple flows simultaneously

---

## How to Access & Use Grafana

### Login
```
URL: http://192.168.11.152:3000
Username: admin
Password: Versa@123!!
```

### View Existing Dashboard
1. Login to Grafana
2. Navigate to: Dashboards → Browse
3. Select: "RDMA Cluster Monitoring - PFC/ECN/CNP"

### Dashboard Panels
1. **ECN-Marked RoCE Packets** - Shows ECN marking activity
2. **CNP Packets** - Congestion Notification Packets
3. **PFC Pause Frames (Priority 3)** - RoCE traffic pause frames
4. **RDMA Write Operations** - RDMA write request rates
5. **Network Throughput** - Bytes per second on all interfaces
6. **Network Packet Drops** - Should be zero (PFC prevents drops)

### Create Custom Query Panel
1. Click **+** → **Add visualization**
2. Select **Prometheus** as data source
3. Enter PromQL query, examples:
   ```promql
   # RDMA operations rate
   rate(rdma_operations{operation="rx_write_requests"}[1m])

   # Network throughput
   rate(network_bytes{interface=~"ens224|ens192"}[1m]) * 8

   # ECN packets (currently 0)
   rdma_ecn_marked_packets
   ```

---

## Recommended Next Steps

### To Generate ECN/PFC Packets:

1. **Increase Traffic Load:**
   ```bash
   # Run more simultaneous flows
   # Use larger message sizes
   # Add more concurrent connections
   ```

2. **Verify Switch Configuration:**
   ```bash
   ssh admin@192.168.50.229
   show interface priority-flow-control
   show qos interface ethernet1/2/2
   ```

3. **Check ECN Configuration:**
   ```bash
   # On servers
   sysctl net.ipv4.tcp_ecn

   # On RDMA interfaces
   rdma system show netdev ens224
   ```

4. **Run Distributed Training:**
   ```bash
   # Use PyTorch distributed training script
   python3 train_distributed_torch.py
   ```
   This generates All-Reduce traffic which is more realistic for AI workloads.

### Monitor in Real-Time:

**Terminal 1 - Watch Metrics:**
```bash
watch -n 2 'curl -s http://192.168.11.152:9101/metrics | grep -E "(rdma_operations|rdma_ecn|pfc_pause)" | grep -v "#"'
```

**Terminal 2 - Grafana Dashboard:**
```
Open: http://192.168.11.152:3000
Set refresh: 5s (top right)
```

**Terminal 3 - Switch Monitoring:**
```bash
ssh admin@192.168.50.229
show interface ethernet1/2/2 counters
show queuing interface ethernet1/2/2
```

---

## Files Referenced

### Scripts Used:
- `saturate_cross_esxi.sh` - Cross-ESXi RDMA traffic generator
- `train_distributed_torch.py` - PyTorch distributed training
- `/tmp/test_ssh.exp` - SSH automation script (created during session)

### Configuration Files:
- `PROMETHEUS_GRAFANA_INSTALLATION_GUIDE.md` - Setup documentation
- `grafana_rdma_dashboard.json` - Dashboard configuration
- `rdma_exporter.py` - Custom RDMA metrics exporter

### Installation Scripts:
- `install_prometheus_server1.sh`
- `install_grafana_server1.sh`
- `install_node_exporter_all_servers.sh`
- `install_rdma_exporter_all_servers.sh`

---

## Session Summary

**Accomplished:**
- ✓ Reviewed Grafana/Prometheus setup
- ✓ Identified monitoring server IP and access credentials
- ✓ Documented PromQL queries for metrics
- ✓ Resolved SSH authentication issues with expect script
- ✓ Started RDMA traffic generation on 7 servers
- ✓ Verified Prometheus collecting metrics (15/17 targets UP)
- ✓ Confirmed Grafana accessible and operational
- ✓ Detected RDMA operations (381K+ writes)

**Current State:**
- RDMA traffic flowing between servers
- Metrics being collected and stored in Prometheus
- Grafana dashboard ready for visualization
- ECN/PFC not triggering (need higher congestion)

**Ready for:**
Monitoring RDMA cluster performance in Grafana at http://192.168.11.152:3000

---

**End of Session**
