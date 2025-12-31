# AI Cluster Inventory

**Date:** 2025-12-28
**Cluster Name:** RDMA AI Cluster
**Total Servers:** 8
**Credentials:** versa / <PASSWORD>

---

## Server Inventory

### RDMA Servers on Vlan251 (Primary Cluster Candidates)

| Server | Hostname | Management IP | RDMA IP (ens192) | Subnet | Status |
|--------|----------|---------------|------------------|--------|--------|
| Server1 | ubunturdma1 | 192.168.11.152 | **192.168.251.111** | Vlan251 | ✅ Ready |
| Server3 | ubunturdma3 | 192.168.11.154 | **192.168.251.113** | Vlan251 | ✅ Ready |
| Server6 | ubunturdma6 | 192.168.12.51 | **192.168.251.116** | Vlan251 | ✅ Ready |
| Server8 | ubunturdma8 | 192.168.30.94 | **192.168.251.118** | Vlan251 | ✅ Ready |

### Additional RDMA Servers on Vlan250

| Server | Hostname | Management IP | RDMA IP (ens192) | Subnet | Status |
|--------|----------|---------------|------------------|--------|--------|
| Server2 | ubunturdma2 | 192.168.11.153 | 192.168.250.112 | Vlan250 | ✅ Ready |
| Server4 | ubunturdma4 | 192.168.11.155 | 192.168.250.114 | Vlan250 | ✅ Ready |
| Server5 | ubunturdma5 | 192.168.11.107 | 192.168.250.115 | Vlan250 | ✅ Ready |
| Server7 | ubunturdma7 | 192.168.20.150 | 192.168.250.117 | Vlan250 | ✅ Ready |

---

## Network Configuration

### Primary RDMA Network (Vlan251)
- **Network:** 192.168.251.0/24
- **Broadcast:** 192.168.251.255
- **Cluster IPs:** .111, .113, .116, .118
- **Purpose:** AI Cluster RDMA traffic
- **Interface:** ens192 (10 Gbps)

### Secondary RDMA Network (Vlan250)
- **Network:** 192.168.250.0/24
- **Broadcast:** 192.168.250.255
- **Cluster IPs:** .112, .114, .115, .117
- **Purpose:** Available for expansion
- **Interface:** ens192 (10 Gbps)

### Management Networks
- **192.168.11.x/23** - Primary management
- **192.168.12.x/23** - Secondary management
- **192.168.20.x/24** - Tertiary management
- **192.168.30.x/24** - Quaternary management
- **Purpose:** SSH access, monitoring
- **Interface:** ens160

---

## Recommended AI Cluster Configuration

### 4-Node Cluster (Vlan251 - Homogeneous Network)
**Recommended for initial deployment:**

1. **ubunturdma1** (192.168.251.111) - Master Node
2. **ubunturdma3** (192.168.251.113) - Worker Node 1
3. **ubunturdma6** (192.168.251.116) - Worker Node 2
4. **ubunturdma8** (192.168.251.118) - Worker Node 3

**Advantages:**
- All on same RDMA subnet (optimal for NCCL)
- Simplified routing and configuration
- Better performance consistency
- Easier troubleshooting

### 8-Node Cluster (All Servers - Heterogeneous Network)
**Available for large-scale workloads:**
- All 8 servers (ubunturdma1-8)
- Requires cross-VLAN RDMA routing
- More complex but greater compute capacity

---

## Next Steps

1. ✅ **Inventory Complete** - All server IPs documented
2. ⏳ **Verify RDMA hardware** on all 4 Vlan251 servers
3. ⏳ **Test RDMA connectivity** between all pairs
4. ⏳ **Install AI/ML stack** (PyTorch + NCCL)
5. ⏳ **Configure distributed training**
6. ⏳ **Run benchmark tests**

---

**Notes:**
- All 8 servers are now active and configured
- ubunturdma5 has an additional interface (192.168.30.25)
- All servers use consistent /24 netmasks for RDMA networks
- Management networks use /23 or /24 netmasks

