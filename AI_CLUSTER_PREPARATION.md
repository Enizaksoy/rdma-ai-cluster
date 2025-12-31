# AI Training Cluster Preparation Guide
**Date:** December 30, 2025
**Cluster:** 8 Ubuntu Servers with Mellanox NICs
**Objective:** Achieve TRUE LOSSLESS network for AI/ML training

---

## Current Infrastructure

### Hardware:
- **Servers:** 8x Ubuntu 24.04 with NVIDIA GPUs
- **NICs:** Mellanox ConnectX (RoCEv2 capable)
- **Switch:** Cisco Nexus 9332PQ (32x 40G ports)
- **Topology:** Leaf-Spine (servers → leaf → spine fabric)

### Network Configuration:
- **Protocol:** RoCEv2 (RDMA over UDP port 4791)
- **MTU:** 9000 on servers, 9216 on switch ✅
- **VLAN 250:** rocep11s0 devices
- **VLAN 251:** rocep19s0 devices

---

## Current Status Assessment

### ✅ **Working Correctly:**

1. **ECN (Explicit Congestion Notification):**
   - Switch WRED ECN: Configured and active
   - Switch marking: ECT → CE (0x2 → 0x3) ✅
   - Receivers seeing CE: 92-101M packets
   - CNP sent: 72-79M packets
   - Senders handling CNP: 3.8M - 81M packets
   - **Egress drops: 0** ✅

2. **PFC (Priority Flow Control):**
   - Configured on CoS 3 (QoS Group 3)
   - Internal fabric: 18-22M pause frames ✅
   - Preventing drops inside fabric ✅

3. **Network Connectivity:**
   - All 8 servers reachable
   - RDMA devices operational
   - Docker installed for monitoring

### ❌ **Issues for AI Training:**

1. **Ingress Packet Drops:**
   ```
   Port: Ethernet1/1/1 (example edge port)
   Ingress MMU Drops: 1,947,420 packets (7.1 GB)
   Drop Rate: 0.29%

   Impact on AI Training:
   - Will cause retransmissions
   - Will slow down All-Reduce synchronization
   - Will extend training time significantly
   ```

2. **Edge Port PFC Inactive:**
   ```
   Edge ports (server-facing): TxPPP: 0, RxPPP: 0
   - PFC not triggering at edge
   - Buffers overflowing before pause sent
   - 91KB buffer too small for microbursts
   ```

3. **Buffer Limitations:**
   ```
   Ingress Buffer: 91KB (hardware-limited on 9332PQ)
   Pause Threshold: 59,357 bytes (65% full)
   Gap to overflow: 31,709 bytes (~2.5μs @ 100Gbps)
   Problem: PFC can't react in 2.5μs
   ```

---

## AI Training Traffic Patterns

### All-Reduce Synchronization (Primary Pattern):

```
Every training iteration (250-500ms):

┌─────────────────────────────────────────────┐
│ PHASE 1: Local Gradient Computation        │
│ - Each GPU: 100-200ms                      │
│ - No network traffic                        │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ PHASE 2: All-Reduce (NETWORK INTENSIVE)    │
│                                             │
│  GPU1 ─┐                          ┌─→ GPU1 │
│  GPU2 ─┤                          ├─→ GPU2 │
│  GPU3 ─┤→ [SUM/AVG GRADIENTS] →──┤─→ GPU3 │
│  GPU4 ─┤   AT SWITCH FABRIC       ├─→ GPU4 │
│  GPU5 ─┤                          ├─→ GPU5 │
│  GPU6 ─┤                          ├─→ GPU6 │
│  GPU7 ─┤                          ├─→ GPU7 │
│  GPU8 ─┘                          └─→ GPU8 │
│                                             │
│ Characteristics:                            │
│ - ALL 8 GPUs send SIMULTANEOUSLY           │
│ - Message size: 100MB - 1GB each           │
│ - Duration: 50-200ms                        │
│ - REQUIRES: 0.00% packet loss              │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ PHASE 3: Weight Update                     │
│ - Each GPU: 10-20ms                        │
│ - No network traffic                        │
└─────────────────────────────────────────────┘

Repeat for millions of iterations (days/weeks)
```

### Traffic Volume Example:

**Small Model (8 GPUs, 1B parameters):**
- Gradient size per iteration: ~4 GB total
- Iterations per second: 2-4
- Network throughput: 8-16 GB/s sustained
- Duration: Hours to days

**Large Model (8 GPUs, 7B+ parameters):**
- Gradient size per iteration: ~28 GB total
- Iterations per second: 0.5-2
- Network throughput: 14-56 GB/s sustained
- Duration: Days to weeks

---

## Action Plan to Achieve Lossless

### **Step 1: Server NIC Optimization** ⚠️ CRITICAL

**Objective:** Reduce microburst behavior, enable proper DCQCN

**Actions:**
1. Enable DCQCN (Data Center Quantized Congestion Notification)
2. Tune PFC on NICs
3. Reduce TX queue depth to prevent large bursts
4. Configure rate limiting

**Script:** `/mnt/c/Users/eniza/Documents/claudechats/tune_nics_for_ai.sh`

**Expected Results:**
- NICs respond faster to CNP packets
- Smaller burst sizes to switch
- Better rate control before buffers fill

### **Step 2: Validation Testing**

**Test 1: Verify Drops Eliminated**
```bash
# On switch, clear counters
clear counters interface ethernet1/1/1

# Run AI training test (see below)

# Check for drops
show queuing interface ethernet1/1/1
```

**Target:** Ingress MMU Drops = 0

**Test 2: Monitor CNP Activity**
```bash
# On servers
rdma statistic show link rocep*/1 | grep -E "cnp|ecn"
```

**Expected:** Higher rp_cnp_handled (more responsive to congestion)

**Test 3: Measure All-Reduce Latency**
```bash
# Use NCCL tests (see Step 3)
./build/all_reduce_perf -b 8M -e 1G -f 2 -g 1
```

**Target:** Consistent latency, no spikes

### **Step 3: AI Training Test Workload**

**Option A: NCCL Bandwidth Test (Recommended)**
```bash
# Install NCCL tests on all 8 servers
git clone https://github.com/NVIDIA/nccl-tests.git
cd nccl-tests
make

# Run All-Reduce test (simulates real AI training)
mpirun -np 8 -H server1,server2,...,server8 \
  ./build/all_reduce_perf -b 128M -e 2G -f 2 -g 1

# This will:
# - Simulate gradient synchronization
# - Test All-Reduce pattern
# - Measure bandwidth and latency
# - Report any errors/timeouts
```

**Option B: PyTorch Distributed Test**
```bash
# Simple PyTorch distributed test
python -m torch.distributed.launch \
  --nproc_per_node=1 \
  --nnodes=8 \
  --node_rank=$RANK \
  --master_addr=192.168.11.152 \
  --master_port=29500 \
  test_allreduce.py
```

**Success Criteria:**
- ✅ No RDMA errors on servers
- ✅ No ingress drops on switch
- ✅ Stable latency (no spikes)
- ✅ Full bandwidth utilization
- ✅ No CNP ignored (all processed)

---

## Monitoring During AI Training

### **Switch Monitoring:**

**Real-time drops:**
```bash
watch -n 1 'show queuing interface ethernet1/1/1 | grep "Ingress MMU"'
```

**PFC activity:**
```bash
watch -n 1 'show interface priority-flow-control | grep "Ethernet1/1"'
```

**ECN WRED stats:**
```bash
show queuing interface ethernet1/1/1 | grep "WRED"
```

### **Server Monitoring:**

**RDMA errors:**
```bash
watch -n 1 'rdma statistic show link rocep11s0/1 | grep -E "timeout|error|drop|cnp"'
```

**CNP handling:**
```bash
watch -n 1 'rdma statistic show link rocep11s0/1 | grep -E "rp_cnp_handled|np_cnp_sent"'
```

---

## Expected Results After Tuning

### **Before (Current State):**
```
Ingress MMU Drops: 1,947,420 (0.29%)
Edge PFC: Inactive (0 pause frames)
AI Training: NOT READY ❌
```

### **After (Target State):**
```
Ingress MMU Drops: 0 (0.00%)
Edge PFC: Active when needed (or ECN preventing need)
CNP Handling: Increased responsiveness
AI Training: READY ✅
```

---

## Fallback Options (If Tuning Insufficient)

If NIC tuning doesn't eliminate drops:

**Option 1: Reduce Incast**
- Stagger All-Reduce operations
- Use Ring All-Reduce instead of Tree
- Implement hierarchical reduce

**Option 2: Traffic Shaping**
- Rate limit at servers (e.g., 80% of line rate)
- Spread traffic over time

**Option 3: Hardware Upgrade** (Last Resort)
- Upgrade to Nexus 9500 series (larger buffers)
- Or use InfiniBand switches (better buffer management)

---

## Summary Checklist

- [ ] Run NIC tuning script on all 8 servers
- [ ] Reboot servers to apply mlxconfig changes
- [ ] Clear switch counters
- [ ] Run NCCL All-Reduce test
- [ ] Verify 0 ingress drops
- [ ] Monitor CNP handling improvement
- [ ] Run actual AI training test workload
- [ ] Document final configuration

**Target:** TRUE LOSSLESS (0.00% drops) for AI/ML training success!

---

**Files Created:**
- `tune_nics_for_ai.sh` - NIC optimization script
- `AI_CLUSTER_PREPARATION.md` - This document
- `ECN_AND_PFC_SESSION_NOTES.md` - Previous ECN/PFC validation
