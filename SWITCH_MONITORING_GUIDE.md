## Switch Monitoring Guide - ECN, PFC, Queue Analysis

**Purpose:** Monitor switch behavior during AI training workload
**Date:** 2025-12-29
**Cluster:** 8-Node RDMA AI Cluster

---

## Quick Start - Run the Test NOW

### Option 1: Automated (Recommended)

```batch
C:\Users\eniza\Documents\claudechats\RUN_STRESS_TEST.bat
```

This will:
1. Check if AI/ML stack is installed
2. Run intensive training (default 5 minutes)
3. Monitor network statistics automatically

### Option 2: Manual Control

**Terminal 1 - Start Training:**
```bash
cd /mnt/c/Users/eniza/Documents/claudechats
./intensive_training.sh 300  # 300 seconds = 5 minutes
```

**Terminal 2 - Monitor Network:**
```bash
cd /mnt/c/Users/eniza/Documents/claudechats
./monitor_network.sh 300
```

---

## What Gets Monitored (Automatic)

The scripts automatically collect:

### On Each Server
✅ **Network Interface Stats**
- RX/TX bytes and packets
- Dropped packets
- Interface errors

✅ **RDMA Counters**
- RDMA RX/TX data and packets
- Port receive/transmit errors
- Symbol errors
- Link recovery events

✅ **PFC Statistics** (if available)
- PFC pause frames sent/received
- Per-priority pause frames

✅ **ECN Indicators**
- CNP (Congestion Notification Packets)
- ICRC errors (can indicate ECN marking)

---

## Switch Commands (Run During Training)

### For Cisco Nexus Switches

**1. Check Queue Depths:**
```
show queuing interface ethernet X/Y
show policy-map interface ethernet X/Y type queuing
```

**2. Check PFC Status:**
```
show interface ethernet X/Y priority-flow-control
show interface ethernet X/Y counters priority-flow-control
```

**3. Check ECN Configuration:**
```
show queuing interface ethernet X/Y
show policy-map type network-qos
```

**4. Monitor Drops:**
```
show interface ethernet X/Y counters
show interface ethernet X/Y counters detailed
```

**5. Real-time Monitoring:**
```
show interface ethernet X/Y counters | i drop
watch 5 show interface ethernet X/Y priority-flow-control
```

### For Arista Switches

**1. Queue Statistics:**
```
show interfaces ethernet X counters queue
show qos interfaces ethernet X
```

**2. PFC Monitoring:**
```
show interfaces ethernet X priority-flow-control
show interfaces ethernet X counters priority-flow-control
```

**3. ECN Stats:**
```
show interfaces ethernet X counters ecn
show qos random-detect ecn counters
```

**4. Buffer Usage:**
```
show hardware capacity utilization
show qos interfaces ethernet X ingress buffer
```

### For Mellanox/NVIDIA Switches

**1. Queue Counters:**
```
show interfaces ethernet X/Y counters queue
show queue
```

**2. PFC Statistics:**
```
show interfaces ethernet X/Y counters pfc
show interfaces ethernet X/Y flow-control
```

**3. ECN Configuration:**
```
show congestion-control
show qos trust
```

**4. Buffer Monitoring:**
```
show queue statistics
show buffers
```

---

## What to Look For During Training

### 🟢 **Normal Behavior**

**Queue Depths:**
- Moderate queue utilization (< 50%)
- Some fluctuation is normal
- No sustained 100% utilization

**PFC Frames:**
- Occasional PFC pause frames (< 1% of traffic)
- Brief pauses during traffic bursts
- Quick recovery

**ECN Marks:**
- Some ECN-marked packets (indicates congestion avoidance working)
- Should see fewer drops with ECN enabled

**Drops:**
- Minimal packet drops (< 0.01%)
- No tail drops

### 🟡 **Warning Signs**

**Queue Depths:**
- Sustained high utilization (> 80%)
- Queues frequently maxed out
- Specific queues always full

**PFC Frames:**
- High rate of PFC pause frames (> 5% of traffic)
- Long pause durations
- Frequent pauses on multiple ports

**ECN Marks:**
- Very high percentage of ECN marks (> 20%)
- ECN marks but still seeing drops

**Drops:**
- Increasing tail drops
- Buffer overruns
- Specific queue drops

### 🔴 **Problem Indicators**

**Queue Depths:**
- Queues consistently at 100%
- Queue overflow errors
- Specific priority starved

**PFC Frames:**
- Continuous PFC pause (head-of-line blocking)
- PFC deadlock
- No traffic flow during pauses

**ECN Marks:**
- ECN not working (configured but no marks)
- 100% packets marked

**Drops:**
- Significant packet loss (> 1%)
- Retransmissions
- Connection timeouts

---

## Expected Results for 10 GbE RDMA

### Good Performance

| Metric | Expected Range | Notes |
|--------|----------------|-------|
| Throughput | 6-8 Gbps per flow | RDMA efficiency |
| Latency | < 10 μs | Without congestion |
| PFC Pause | < 1% of time | Brief, infrequent |
| ECN Marks | 1-5% of packets | Active congestion avoidance |
| Drops | < 0.001% | Near zero |
| Queue Depth | 20-60% avg | Healthy buffering |

### With Congestion (During Intensive Training)

| Metric | Acceptable Range | Notes |
|--------|------------------|-------|
| Throughput | 5-7 Gbps per flow | Slight reduction OK |
| Latency | 10-100 μs | Some increase expected |
| PFC Pause | 1-10% of time | Moderate pausing |
| ECN Marks | 5-15% of packets | ECN actively managing |
| Drops | < 0.1% | Minimal with PFC/ECN |
| Queue Depth | 60-90% avg | Higher utilization |

---

## Sample Switch Configuration

### Cisco Nexus - RoCE/RDMA Setup

```
! Enable PFC on lossless class
class-map type network-qos match-any cnp
  match cos 3

policy-map type network-qos rdma_policy
  class type network-qos cnp
    pause no-drop
    mtu 9216

system qos
  service-policy type network-qos rdma_policy

! ECN Configuration
policy-map type queuing rdma_queue
  class type queuing class-default
    random-detect minimum-threshold 150 kbytes maximum-threshold 1500 kbytes drop-probability 2
    random-detect ecn

! Apply to interfaces
interface ethernet 1/1-48
  service-policy type queuing output rdma_queue
  priority-flow-control mode on
  priority-flow-control watch-dog-interval off
```

### Arista - RoCE Configuration

```
! QoS Trust DSCP
qos trust dscp

! ECN Configuration
qos random-detect ecn minimum-threshold 150 kbytes maximum-threshold 1500 kbytes drop-probability 5

! PFC Configuration
priority-flow-control mode on
priority-flow-control priority 3 no-drop

! Apply to interfaces
interface Ethernet1-48
  qos trust dscp
  priority-flow-control mode on
  priority-flow-control priority 3 no-drop
```

---

## Analyzing Results

### After Training Completes

**1. Check Server-Side Statistics:**
```bash
# View monitoring log
cat /mnt/c/Users/eniza/Documents/claudechats/network_monitor_*.log

# Look for errors
grep "Errors:" network_monitor_*.log

# Check RDMA traffic
grep "RDMA:" network_monitor_*.log | tail -20
```

**2. Calculate Statistics:**
```bash
# Average throughput per server
grep "RDMA: RX" network_monitor_*.log | awk '{sum+=$3} END {print sum/NR " MB/s avg"}'

# Check for drops
grep "Drops:" network_monitor_*.log | grep -v "RX 0, TX 0"
```

**3. Compare Before/After:**
- Note starting vs ending counters
- Calculate total data transferred
- Identify which servers saw the most traffic

---

## Troubleshooting

### High PFC Pause Frames

**Causes:**
- Buffer too small
- ECN thresholds too high
- Incast traffic pattern

**Solutions:**
- Increase buffer allocation
- Lower ECN marking threshold
- Tune NCCL ring/tree algorithms

### No ECN Marks Seen

**Causes:**
- ECN not configured on switch
- ECN threshold too high
- Not enough traffic to trigger

**Solutions:**
- Verify ECN configuration
- Lower ECN min threshold
- Increase training intensity

### Packet Drops Despite PFC

**Causes:**
- PFC not enabled on all hops
- Buffer exhaustion before PFC
- Pause delay too long

**Solutions:**
- Enable PFC on all switches in path
- Increase buffer size
- Check cable/transceiver issues

### Queue Imbalance

**Causes:**
- Hashing algorithm issue
- Specific flows oversubscribed
- QoS misconfiguration

**Solutions:**
- Review ECMP hashing
- Check flow distribution
- Verify QoS class mapping

---

## Next Steps After Testing

1. **Review Results:**
   - Analyze network_monitor_*.log
   - Check switch counters
   - Document any issues

2. **Tune Configuration:**
   - Adjust ECN thresholds if needed
   - Modify PFC settings if necessary
   - Optimize queue scheduling

3. **Repeat Test:**
   - Run longer duration (30-60 minutes)
   - Try different model sizes
   - Test with GPU training if available

4. **Optimize:**
   - Fine-tune switch buffers
   - Adjust NCCL parameters
   - Consider jumbo frames (MTU 9000)

---

## Useful Commands Reference

### Check Current Config
```bash
# On servers - check interface
ssh versa@192.168.11.152 "ip addr show ens224"

# Check RDMA device status
ssh versa@192.168.11.152 "ibv_devinfo | grep -A 20 state"

# Monitor live traffic
ssh versa@192.168.11.152 "iftop -i ens224"
```

### During Training
```bash
# Watch RDMA counters (live)
watch -n 1 'ssh versa@192.168.11.152 "cat /sys/class/infiniband/rocep19s0/ports/1/counters/port_xmit_data"'

# Monitor drops
watch -n 1 'ssh versa@192.168.11.152 "cat /sys/class/net/ens224/statistics/tx_dropped"'
```

---

**Created:** 2025-12-29
**Version:** 1.0
**Status:** Ready for Testing
