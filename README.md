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

## 🎯 Project Overview

This repository contains comprehensive documentation, configuration scripts, and performance analysis for building a lossless RDMA (Remote Direct Memory Access) network optimized for distributed AI/ML training workloads.

### What's Inside

- **Complete technical documentation** for RDMA/RoCEv2 configuration
- **PFC (Priority Flow Control)** implementation guide
- **ECN (Explicit Congestion Notification)** setup and validation
- **AI training integration** with PyTorch + Horovod
- **30+ automation scripts** for configuration, testing, and monitoring
- **Performance benchmarks** and comparison with TCP
- **Troubleshooting guides** for common issues

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   8-Node AI Training Cluster                │
│                                                             │
│  Ubuntu Servers (x8) with Mellanox ConnectX-4 Lx NICs      │
│         ↓                                                    │
│  Cisco Nexus Switch (100G, PFC + ECN enabled)               │
│         ↓                                                    │
│  RoCEv2 (RDMA over Converged Ethernet v2)                   │
│         ↓                                                    │
│  Lossless Network for AI Training                           │
└─────────────────────────────────────────────────────────────┘
```

**Key Technologies:**
- RoCEv2 (RDMA over Converged Ethernet)
- Priority Flow Control (PFC / IEEE 802.1Qbb)
- Explicit Congestion Notification (ECN / RFC 3168)
- DCQCN (Data Center Quantized Congestion Notification)

## 📚 Documentation

### Main Guides


- **[Technical Writeup](GITHUB_TECHNICAL_WRITEUP.md)** - Comprehensive technical documentation

### Configuration Guides

- **[ECN and PFC Session Notes](ECN_AND_PFC_SESSION_NOTES.md)** - Complete ECN/PFC implementation
- **[PFC Success Summary](PFC_SUCCESS_SUMMARY.md)** - Configuration results and validation
- **[PFC Configuration Summary](PFC_CONFIGURATION_SUMMARY.md)** - Step-by-step configuration
- **[How to Check PFC](HOW_TO_CHECK_PFC.md)** - Multi-level verification guide

### Performance & Testing

- **[RDMA Performance Testing Summary](RDMA_Performance_Testing_Summary.md)** - Detailed benchmarks
- **[AI Training Observation Guide](AI_TRAINING_OBSERVATION_GUIDE.md)** - Monitor RDMA during training

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

### 3. Verify Configuration

```bash
# Check PFC status
bash check_pfc_config.sh

# Check server configuration
bash check_server_pfc.sh
```

### 4. Run Performance Tests

```bash
# RDMA bandwidth test
bash test_rdma_bandwidth.sh

# Cross-host traffic test
bash saturate_cross_esxi.sh 60
```

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

### 2. RDMA Kernel Bypass
Regular `tcpdump` won't show RDMA traffic - use `mellanox/tcpdump-rdma` Docker container.

### 3. PFC vs Global Flow Control
- **Global Pause (802.3x):** Stops ALL traffic
- **PFC (802.1Qbb):** Pauses only specific priority classes

### 4. 100% Utilization is Normal
With proper PFC/ECN, 100% link utilization with 0 drops is **optimal operation**.

### 5. CNP Flow is Elegant
DCQCN algorithm prevents congestion before packet loss occurs.

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

**Quick Checks:**
```bash
# Check RDMA devices
rdma link show

# Check PFC status
sudo lldptool -t -i ens224 -V PFC

# Check RDMA statistics
rdma statistic show link rocep19s0/1 | grep -Ei "cnp|ecn"
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

**Status:** ✅ Production Ready | **Last Updated:** December 2024

**⭐ If you find this useful, please star the repository!**

