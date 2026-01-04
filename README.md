# RDMA Network for AI Training - Complete Guide

> Building a lossless, high-performance RDMA network for distributed AI training with PFC and ECN

[![Performance](https://img.shields.io/badge/Bandwidth-9.23_Gbps-brightgreen)]()
[![Latency](https://img.shields.io/badge/Latency-14.37_μs-blue)]()
[![Packet_Loss](https://img.shields.io/badge/Packet_Loss-96%25_Reduction-success)]()
[![Status](https://img.shields.io/badge/Status-Production_Ready-green)]()

## 📊 Achievement Highlights

- **96% reduction in packet drops** (6.5M → 256K packets)
- **2x bandwidth improvement** over TCP (9.23 Gbps vs 4.67 Gbps)
- **11x lower latency** than TCP (14.37 μs vs 161 μs)
- **Sub-microsecond jitter** (0.82 μs standard deviation)
- **Zero packet loss** at 100% link utilization
- **Production-ready** distributed AI training infrastructure
- **Complete observability** with Prometheus + Grafana monitoring
- **40M+ ECN-marked packets** proving congestion control works
- **133M+ pause frames** on ESXi hosts for lossless operation

### Live Dashboard Examples

**RDMA Monitoring Dashboard:**

![RDMA Dashboard](grafanardma%20server.jpg)

**Switch PFC Monitoring Dashboard:**

![Switch Dashboard](grafananexus.jpg)

## 🎯 Project Overview

This repository contains comprehensive documentation, configuration scripts, and performance analysis for building a lossless RDMA (Remote Direct Memory Access) network optimized for distributed AI/ML training workloads.

### What's Inside

- **Complete technical documentation** for RDMA/RoCEv2 configuration
- **PFC (Priority Flow Control)** implementation guide
- **ECN (Explicit Congestion Notification)** setup and validation
- **Prometheus + Grafana monitoring stack** for full observability
- **Custom exporters** for RDMA stats, ESXi metrics, and switch monitoring
- **AI training integration** with PyTorch + Horovod
- **30+ automation scripts** for configuration, testing, and monitoring
- **Performance benchmarks** and comparison with TCP
- **Troubleshooting guides** for common issues

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Grafana Dashboard                       │
│              Real-time RDMA Network Monitoring               │
│  ECN/CNP Stats | ESXi Pause Frames | Switch PFC Metrics     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                  Prometheus (Port 9090)                      │
│  Collecting from: RDMA Exporters | ESXi | Switch            │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                   8-Node AI Training Cluster                 │
│                                                              │
│  Ubuntu Servers (x8) with Mellanox ConnectX-4 Lx NICs       │
│         ↓                                                     │
│  Cisco Nexus Switch (100G, PFC + ECN enabled)                │
│         ↓                                                     │
│  RoCEv2 (RDMA over Converged Ethernet v2)                    │
│         ↓                                                     │
│  Lossless Network for AI Training                            │
└──────────────────────────────────────────────────────────────┘
```

**Key Technologies:**
- RoCEv2 (RDMA over Converged Ethernet)
- Priority Flow Control (PFC / IEEE 802.1Qbb)
- Explicit Congestion Notification (ECN / RFC 3168)
- DCQCN (Data Center Quantized Congestion Notification)
- Prometheus + Grafana (Observability Stack)
- Custom Python Exporters (RDMA, ESXi, Switch metrics)

## 📚 Documentation

### Main Guides

- **[LinkedIn Post - RDMA Setup](LINKEDIN_POST.md)** - Professional summary with key learnings
- **[LinkedIn Post - Monitoring](LINKEDIN_POST_MONITORING.md)** - Prometheus/Grafana observability stack
- **[Technical Writeup](GITHUB_TECHNICAL_WRITEUP.md)** - Comprehensive technical documentation

### Configuration Guides

- **[ECN and PFC Session Notes](ECN_AND_PFC_SESSION_NOTES.md)** - Complete ECN/PFC implementation
- **[PFC Success Summary](PFC_SUCCESS_SUMMARY.md)** - Configuration results and validation
- **[PFC Configuration Summary](PFC_CONFIGURATION_SUMMARY.md)** - Step-by-step configuration
- **[How to Check PFC](HOW_TO_CHECK_PFC.md)** - Multi-level verification guide
- **[Prometheus/Grafana Installation](PROMETHEUS_GRAFANA_INSTALLATION_GUIDE.md)** - Monitoring stack setup
- **[Working Configuration](WORKING_CONFIG_2026-01-03.md)** - Current working config and exporters

### Performance & Testing

- **[RDMA Performance Testing Summary](RDMA_Performance_Testing_Summary.md)** - Detailed benchmarks
- **[AI Training Observation Guide](AI_TRAINING_OBSERVATION_GUIDE.md)** - Monitor RDMA during training
- **[Session 2026-01-04](SESSION_2026-01-04.md)** - Complete monitoring implementation session notes
- **[Session 2026-01-03](SESSION_2026-01-03_GRAFANA_PFC_NEXUS.md)** - Grafana and switch monitoring setup
- **[Session 2026-01-02](SESSION_2026-01-02_GRAFANA_RDMA_TESTING.md)** - Initial Grafana integration

### Reference Documentation

- **[AI Cluster Inventory](AI_CLUSTER_INVENTORY.md)** - Hardware and network topology
- **[AI Cluster Preparation](AI_CLUSTER_PREPARATION.md)** - Initial setup guide
- **[Switch Monitoring Guide](SWITCH_MONITORING_GUIDE.md)** - Cisco Nexus monitoring
- **[Quick Reference](QUICK_REFERENCE.md)** - Common commands and procedures

## 🚀 Quick Start

### 1. Prerequisites

- RDMA-capable NICs (Mellanox ConnectX series)
- Switch with PFC/ECN support (Cisco Nexus, Arista, etc.)
- Ubuntu 22.04 or similar Linux distribution
- RoCEv2 support enabled

### 2. PFC Configuration

```bash
# On servers
bash enable_pfc_rdma_interfaces.sh

# On switch (Cisco Nexus)
bash enable_flowcontrol_switch.sh
```

### 3. Install Monitoring Stack

```bash
# Install Prometheus and Grafana
bash install_prometheus_server1.sh
bash install_grafana_server1.sh

# Deploy exporters to all servers
bash install_rdma_exporter_all_servers.sh

# Deploy RDMA stats exporter
python3 rdma_stats_exporter.py  # Port 9103

# Deploy ESXi stats exporter
python3 esxi_stats_exporter.py  # Port 9104

# Import Grafana dashboards
# - grafana_rdma_dashboard_fixed.json
# - grafana_nexus_switch_dashboard_final.json
```

### 4. Verify Configuration

```bash
# Check PFC status
bash check_pfc_config.sh

# Check server configuration
bash check_server_pfc.sh

# Verify exporters are running
curl http://localhost:9103/metrics | grep rdma_ecn
curl http://localhost:9104/metrics | grep esxi_pause
curl http://localhost:9102/metrics | grep nexus_pfc
```

### 5. Run Performance Tests

```bash
# RDMA bandwidth test
bash test_rdma_bandwidth.sh

# Cross-host traffic test with monitoring
bash saturate_cross_esxi.sh 60

# Or use traffic controller
./rdma_traffic_controller.py start
./rdma_traffic_controller.py status
./rdma_traffic_controller.py stop
```

### 6. View Metrics in Grafana

```bash
# Access Grafana
http://192.168.11.152:3000

# Default credentials: admin / Versa@123!!

# Key dashboards:
# - "RDMA Cluster Monitoring - Fixed"
# - "Nexus Switch Monitoring - PFC and Traffic"
```

**RDMA Server Dashboard - ECN/CNP Metrics:**

![RDMA Server Dashboard](grafanardma%20server.jpg)
*Real-time RDMA statistics showing 40M+ ECN-marked packets, 34M+ CNP packets sent, and complete congestion control metrics*

**Nexus Switch Dashboard - PFC and QoS:**

![Nexus Switch Dashboard](grafananexus.jpg)
*Switch-level monitoring showing PFC frames on internal fabric (ii ports), QoS Group 3 traffic, and MMU statistics*

## 🛠️ Scripts & Tools

### Configuration Scripts (10+)
- `enable_pfc_rdma_interfaces.sh` - Configure PFC on servers
- `enable_flowcontrol_switch.sh` - Enable PFC on switch
- `enable_pfc_esxi_rdma.sh` - Configure PFC on ESXi hosts
- `detect_rdma_interfaces.sh` - Auto-detect RDMA interfaces
- And more...

### Testing Scripts (8+)
- `test_rdma_bandwidth.sh` - Bandwidth validation
- `test_rdma_cross_vlan.sh` - Cross-VLAN testing
- `saturate_cross_esxi.sh` - Multi-host traffic generation
- `monitored_rdma_test.sh` - RDMA test with monitoring
- And more...

### Monitoring Scripts (10+)
- `monitor_pfc_all_levels.sh` - Multi-level PFC monitoring
- `monitor_network.sh` - Network-wide monitoring
- `check_ecn_stats.sh` - ECN statistics
- `check_sender_cnp.sh` - CNP packet tracking
- And more...

### Prometheus Exporters (NEW!)
- `rdma_stats_exporter.py` - RDMA ECN/CNP statistics exporter (port 9103)
- `esxi_stats_exporter.py` - ESXi pause frame metrics exporter (port 9104)
- `nexus_prometheus_exporter.py` - Nexus switch PFC/QoS exporter (port 9102)
- `rdma_exporter.py` - Node-level RDMA exporter (port 9101)

### Grafana Dashboards
- `grafana_rdma_dashboard_fixed.json` - Complete RDMA monitoring with ECN/CNP/ESXi metrics
- `grafana_nexus_switch_dashboard_final.json` - Switch PFC and QoS monitoring
- Includes 12+ panels showing real-time congestion control metrics
- Screenshots: `grafanardma server.jpg`, `grafananexus.jpg` - Live dashboard examples

### Traffic Control Tools
- `rdma_traffic_controller.py` - Start/stop/status for RDMA traffic generation
- `saturate_for_ecn.py` - Generate traffic to trigger ECN marking

### AI Training Scripts (5+)
- `install_ai_training_stack.sh` - Install PyTorch + Horovod
- `train_distributed.py` - Distributed training script
- `monitor_training_traffic.sh` - Training traffic monitoring
- And more...

### Capture & Analysis (5+)
- `capture_ecn_pcap.sh` - Capture ECN bits
- `capture_ecn_all_servers.sh` - Multi-server capture
- Docker container: `mellanox/tcpdump-rdma` for RDMA packet capture

## 📈 Performance Results

### RDMA vs TCP Comparison

| Metric | TCP (iperf) | RDMA (ib_send) | Improvement |
|--------|-------------|----------------|-------------|
| **Bandwidth** | 4.67 Gbps | 9.23 Gbps | **+98%** (2x) |
| **Latency** | 161 μs | 14.37 μs | **-91%** (11x) |
| **Jitter** | Unknown | 0.82 μs | Outstanding |
| **CPU Usage** | High | Low | Offloaded |
| **Packet Loss** | Possible | 0 | Lossless |

### Latency Optimization Journey

```
Initial (Untuned)  →  Tuned  →  Optimized
     ↓                  ↓           ↓
  52.07 μs         14.85 μs    14.37 μs   (Average)
  114.54 μs        10.09 μs    0.82 μs    (Std Dev)
  626.09 μs        355.28 μs   21.70 μs   (Maximum)
```

**72% latency reduction, 99% jitter reduction**

## 🔍 Key Technical Findings

### 1. ECN Marking Location
**The switch does ECN marking, not the NICs!**

```
Sender NIC  → Sets ECT bits (tos 0x2)
Switch      → Marks ECT → CE (tos 0x3) ← THE MARKER
Receiver    → Generates CNP
Sender      → Reduces rate
```

**Proof from monitoring:** 40M+ `np_ecn_marked_roce_packets` on servers shows switch is marking!

### 2. RDMA Kernel Bypass
Regular `tcpdump` won't show RDMA traffic - use `mellanox/tcpdump-rdma` Docker container.

### 3. PFC vs Global Flow Control
- **Global Pause (802.3x):** Stops ALL traffic
- **PFC (802.1Qbb):** Pauses only specific priority classes

### 4. 100% Utilization is Normal
With proper PFC/ECN, 100% link utilization with 0 drops is **optimal operation**.

### 5. CNP Flow is Elegant
DCQCN algorithm prevents congestion before packet loss occurs.

### 6. Two-Layer Congestion Control (PROVEN!)
Our monitoring revealed both layers working simultaneously:
- **Layer 2 (PFC):** Switch ↔ ESXi (133M+ pause frames)
- **Layer 3 (ECN/CNP):** Server ↔ Server (40M+ ECN packets, 34M+ CNP)

### 7. Switch Internal Fabric Needs Monitoring
126M+ PFC frames on internal ii ports vs 0 on physical ports - internal fabric manages congestion before it reaches servers!

## 🎓 Use Cases

**Ideal for:**
- ✅ Distributed AI/ML training (PyTorch, TensorFlow, Horovod)
- ✅ Storage (NVMe-oF, iSER, iSCSI extensions)
- ✅ Databases (distributed, in-memory)
- ✅ HPC (scientific computing, simulations)
- ✅ Big Data (Hadoop, Spark with RDMA)
- ✅ Low-latency financial systems

## 🔧 Requirements

**Hardware:**
- RDMA-capable NICs (Mellanox/NVIDIA ConnectX-4 or newer)
- Switch with DCB/PFC support
- 10GbE or higher network

**Software:**
- Ubuntu 22.04 LTS (or similar)
- rdma-core, libibverbs
- lldpad (for PFC/DCB)
- perftest tools (ib_send_bw, ib_send_lat)

**Optional:**
- PyTorch, Horovod (for AI training)
- OpenMPI with UCX (for RDMA-aware MPI)

## 📊 Network Topology

**8-Server Configuration:**
- 2x ESXi hosts running 8 Ubuntu VMs
- Cisco Nexus switch with 100G ports
- Mellanox ConnectX-4 Lx NICs (RoCEv2)
- MTU: 9216 (switch), 9000 (servers)

See [AI_CLUSTER_INVENTORY.md](AI_CLUSTER_INVENTORY.md) for detailed topology.

## 🐛 Troubleshooting

Common issues and solutions are documented in:
- [GITHUB_TECHNICAL_WRITEUP.md](GITHUB_TECHNICAL_WRITEUP.md#troubleshooting-guide)
- [HOW_TO_CHECK_PFC.md](HOW_TO_CHECK_PFC.md)

**Quick Checks via Monitoring APIs:**
```bash
# Check RDMA stats exporter
curl http://192.168.11.152:9103/metrics | grep rdma_ecn_marked_packets
# Expected: rdma_ecn_marked_packets{...} 40000000+

# Check ESXi stats exporter
curl http://192.168.11.152:9104/metrics | grep esxi_pause_rx_phy
# Expected: esxi_pause_rx_phy{host="esxi1",vmnic="vmnic5"} 133000000+

# Check Switch stats exporter
curl http://192.168.11.152:9102/metrics | grep nexus_pfc
# Expected: nexus_pfc_rx_frames{interface="ii1/1/1"} 126000000+

# Check Prometheus targets status
curl http://192.168.11.152:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .job, health: .health}'

# Query metrics from Prometheus API
curl 'http://192.168.11.152:9090/api/v1/query?query=rdma_ecn_marked_packets' | jq
```

## 📝 License

This documentation and scripts are provided as-is for educational and reference purposes.

## 🤝 Contributing

This is a documentation repository. Feel free to:
- Open issues for questions
- Suggest improvements
- Share your own RDMA experiences

## 📧 Contact

- GitHub: [@Enizaksoy](https://github.com/Enizaksoy)

## 🙏 Acknowledgments

- Mellanox/NVIDIA for RDMA documentation and tools
- Cisco for Nexus switch documentation
- OpenMPI and UCX communities
- PyTorch and Horovod projects

---

## 📊 Monitoring Stack Configuration

### Prometheus Scrape Configuration

Add these jobs to `/etc/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  # RDMA server statistics (ECN/CNP metrics)
  - job_name: 'rdma-servers'
    scrape_interval: 15s
    static_configs:
      - targets:
          - '192.168.11.152:9103'
          - '192.168.11.153:9103'
          - '192.168.11.154:9103'
          - '192.168.11.155:9103'
          - '192.168.11.107:9103'
          - '192.168.12.51:9103'
          - '192.168.20.150:9103'
          - '192.168.30.94:9103'
        labels:
          cluster: 'rdma'
          metric_type: 'rdma_stats'

  # ESXi pause frame statistics
  - job_name: 'esxi-hosts'
    scrape_interval: 15s
    static_configs:
      - targets: ['192.168.11.152:9104']
        labels:
          cluster: 'rdma'
          metric_type: 'esxi_pause'

  # Nexus switch PFC/QoS statistics
  - job_name: 'nexus-switch'
    scrape_interval: 30s
    static_configs:
      - targets: ['192.168.11.152:9102']
        labels:
          cluster: 'rdma'
          metric_type: 'switch_pfc'
```

### RDMA Stats Exporter Configuration

Python Flask exporter collecting from `rdma statistic show`:

```python
# Key metrics exported:
METRICS = {
    'np_ecn_marked_roce_packets': 'rdma_ecn_marked_packets',  # ECN marking by switch
    'np_cnp_sent': 'rdma_cnp_sent',                           # CNP notifications sent
    'rp_cnp_handled': 'rdma_cnp_handled',                     # Rate reductions
    'rx_write_requests': 'rdma_rx_write_requests',            # RDMA operations
    'out_of_sequence': 'rdma_out_of_sequence',                # Reordering events
}

# Example metric output:
# rdma_ecn_marked_packets{host="ubunturdma5",device="rocep11s0",port="1"} 40394737
# rdma_cnp_sent{host="ubunturdma5",device="rocep11s0",port="1"} 34569335
```

### ESXi Stats Exporter Configuration

Python exporter using SSH to collect from `vsish`:

```python
# ESXi hosts configuration
ESXI_HOSTS = {
    "esxi1": {
        "ip": "192.168.50.32",
        "vmnics": ["vmnic5", "vmnic6"],
    },
    "esxi2": {
        "ip": "192.168.50.152",
        "vmnics": ["vmnic3", "vmnic4"],
    }
}

# Example metric output:
# esxi_pause_rx_phy{host="esxi1",vmnic="vmnic5",esxi_ip="192.168.50.32"} 133704835
# esxi_pause_rx_transitions{host="esxi1",vmnic="vmnic5",esxi_ip="192.168.50.32"} 66852436
```

### Grafana Dashboard Queries

Example PromQL queries used in dashboards:

```promql
# ECN-marked packets rate (packets/sec)
rate(rdma_ecn_marked_packets[1m])

# CNP packets sent rate
rate(rdma_cnp_sent[1m])

# ESXi pause frames rate (showing congestion)
rate(esxi_pause_rx_phy[1m])

# Switch internal fabric PFC frames
rate(nexus_pfc_rx_frames{interface=~"ii.*"}[1m])

# Total RDMA write operations across cluster
sum(rate(rdma_rx_write_requests[5m]))
```

### Metrics Available

**Server-Side RDMA Metrics (Port 9103):**
- `rdma_ecn_marked_packets` - Packets marked by switch (40M+ in production!)
- `rdma_cnp_sent` - CNP notifications sent by receivers (34M+)
- `rdma_cnp_handled` - Rate reductions performed by senders (9M+)
- `rdma_rx_write_requests` - RDMA write operations (306M+)
- `rdma_out_of_sequence` - Packet reordering events

**ESXi Hypervisor Metrics (Port 9104):**
- `esxi_pause_rx_phy` - Physical pause frames received (133M+ on vmnic5!)
- `esxi_pause_tx_phy` - Physical pause frames transmitted
- `esxi_pause_rx_transitions` - Pause state changes (66M+)
- `esxi_pause_storm_warnings` - Pause storm warnings

**Switch Metrics (Port 9102):**
- `nexus_pfc_rx_frames` - PFC frames received per interface
- `nexus_pfc_tx_frames` - PFC frames transmitted per interface
- `nexus_qos_group_packets` - QoS Group 3 traffic (3TB+ RDMA)
- `nexus_mmu_drops` - Buffer overflow drops (should be 0!)

All metrics include labels for granular filtering by host, interface, vmnic, etc.

---

**Status:** ✅ Production Ready with Full Observability | **Last Updated:** January 2026

**⭐ If you find this useful, please star the repository!**
