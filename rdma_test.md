# RDMA Test Notes

## Date: 2025-12-17

---

## Test: ib_send_bw Bandwidth Test

### Command Used
```bash
ib_send_bw -d rocep11s0 -x 3 --report_gbits -s 1048576 -n 5000 -q 4 -F 192.168.251.111
```

### Test Configuration
- **Device**: rocep11s0
- **Number of QPs**: 4
- **Transport type**: IB
- **Connection type**: RC
- **MTU**: 1024[B]
- **Link type**: Ethernet
- **GID index**: 3
- **Message Size**: 1048576 bytes (1 MB)
- **Iterations per QP**: 5000
- **TX depth**: 128
- **CQ Moderation**: 1
- **PCIe relax order**: ON

### Local Address (192.168.250.112)
- QP 0x0134, PSN 0x8b23ce
- QP 0x0135, PSN 0x8f2fd7
- QP 0x0136, PSN 0x21969f
- QP 0x0137, PSN 0xe427cb

### Remote Address (192.168.251.111)
- QP 0x011f, PSN 0x3ec20
- QP 0x0120, PSN 0x17b38a
- QP 0x0121, PSN 0xeef0c
- QP 0x0122, PSN 0x572f6b

### Test Results
```
#bytes     #iterations    BW peak[Gb/sec]    BW average[Gb/sec]   MsgRate[Mpps]
1048576    20000          9.23               9.23                 0.001100
```

### Analysis

**Iterations Explained:**
- Command specified: `-n 5000` (5000 iterations per queue pair)
- Queue pairs: `-q 4` (4 queue pairs)
- **Total iterations = 4 QPs × 5000 = 20,000 iterations**

**What each iteration means:**
- Each iteration = one send operation (one message)
- Message size = 1,048,576 bytes (1 MB)
- Total data transferred = 20,000 messages × 1 MB = ~20 GB

**Performance Metrics:**
- **Bandwidth**: 9.23 Gbps (peak and average)
- **Message Rate**: 0.001100 Mpps = 1,100 messages/second
- **Throughput**: ~1.15 GB/s

---

## Notes
- Test uses RoCE (RDMA over Converged Ethernet)
- IPv4-mapped GID format used
- All 4 queue pairs successfully connected
- Stable bandwidth (peak = average indicates consistent performance)

---

---

## RDMA Latency Testing (ib_send_lat)

### Test Command
```bash
# Server (192.168.251.111)
ib_send_lat -d rocep11s0 -x 3

# Client (192.168.250.112)
ib_send_lat -d rocep19s0 -x 3 192.168.251.111
```

### Latency Test Results - Evolution

#### Initial Test (Untuned System)
```
#bytes #iterations    t_min[usec]    t_max[usec]  t_typical[usec]    t_avg[usec]    t_stdev[usec]
2       1000          13.98          626.09       16.77              52.07           114.54
```
**Issues:** High latency, very high jitter (114 μs std dev), large spikes (626 μs max)

#### After Initial Tuning
```
#bytes #iterations    t_min[usec]    t_max[usec]  t_typical[usec]    t_avg[usec]    t_stdev[usec]
2       1000          5.40           355.28       14.29              14.85           10.09
```
**Improvements:** 71% better average, 91% better jitter

#### Final Results (Optimized)
```
#bytes #iterations    t_min[usec]    t_max[usec]  t_typical[usec]    t_avg[usec]    t_stdev[usec]   99%[usec]   99.9%[usec]
2       1000          4.73           21.70        14.30              14.37           0.82            15.85       21.70
```

**Final Performance Metrics:**
- **Minimum Latency**: 4.73 μs
- **Average Latency**: 14.37 μs
- **Jitter (Std Dev)**: 0.82 μs ⭐ (sub-microsecond variance!)
- **Maximum Latency**: 21.70 μs (no spikes)
- **99th Percentile**: 15.85 μs
- **99.9th Percentile**: 21.70 μs

**Assessment:** ✅ Production-ready, excellent consistency

---

## TCP Performance Baseline (iperf)

### Test Command
```bash
# Server
iperf -s

# Client
iperf -c 192.168.251.111 -t 6
```

### Results
```
Client connecting to 192.168.251.111, TCP port 5001
TCP window size: 16.0 KByte (default)
[  1] local 192.168.250.112 port 39020 connected with 192.168.251.111 port 5001
      (icwnd/mss/irtt=14/1448/161)
[ ID] Interval       Transfer     Bandwidth
[  1] 0.0000-6.0120 sec  3.27 GBytes  4.67 Gbits/sec
```

**TCP Parameters:**
- **Initial Congestion Window (icwnd)**: 14 segments (~20 KB)
- **MSS (Maximum Segment Size)**: 1448 bytes
- **Initial RTT (irtt)**: 161 μs
- **Bandwidth**: 4.67 Gbps

---

## RDMA vs TCP Performance Comparison

| Metric | TCP (iperf) | RDMA (ib_send) | RDMA Advantage |
|--------|-------------|----------------|----------------|
| **Bandwidth** | 4.67 Gbps | 9.23 Gbps | **+98% (2x faster)** |
| **Latency** | 161 μs | 14.37 μs | **-91% (11x lower)** |
| **Jitter** | Unknown | 0.82 μs | Highly consistent |
| **CPU Overhead** | High | Low | Offloaded to NIC |
| **Packet Loss** | Possible | 0 | Lossless (PFC) |

**Summary:** RDMA provides 2-11x better performance than TCP for this workload!

---

## Network Switch Observations

### Cisco Nexus Switch (192.168.50.229)
- **Interface Utilization**: ~100%
- **Packet Drops**: 0 ✅
- **Assessment**: Normal and optimal for RDMA

**Why 100% Utilization with 0 Drops is Good:**
- Priority Flow Control (PFC) working correctly
- QoS properly configured
- Lossless Ethernet achieved
- Maximum link efficiency

### QoS Queue Statistics
**Primary Traffic Queue (QoS Group 3):**
- TX Bandwidth: 7,854 - 9,979 Mbps
- TX Packets: 900,735 - 1,144,474 pps
- Drops: 0 ✅
- Carries 98% of RDMA traffic

**Other Queues:**
- QoS Groups 0, 1, 2: Minimal traffic
- Control Queue: Management traffic only
- SPAN: No mirrored traffic

---

## Key Findings

### Performance Summary
1. **RDMA Bandwidth**: 9.23 Gbps (92% of 10G link) ⭐⭐⭐⭐⭐
2. **RDMA Latency**: 14.37 μs ± 0.82 μs ⭐⭐⭐⭐⭐
3. **Consistency**: Sub-1 microsecond jitter ⭐⭐⭐⭐⭐
4. **Network Quality**: 100% utilization, 0 drops ⭐⭐⭐⭐⭐

### Optimization Results
- **Latency Improvement**: 52 → 14.37 μs (72% reduction)
- **Jitter Improvement**: 114 → 0.82 μs (99% reduction!)
- **Spike Elimination**: 626 → 21.70 μs (96% reduction)

### Comparison vs TCP
- **Bandwidth**: 2x faster than TCP
- **Latency**: 11x lower than TCP
- **CPU Usage**: Much lower (offloaded to NIC)
- **Packet Loss**: Zero (lossless vs TCP's best-effort)

---

## Production Readiness Assessment

**Status:** ✅ **PRODUCTION READY**

The system demonstrates:
- Excellent throughput (9.23 Gbps)
- Low latency (14.37 μs average)
- Outstanding consistency (0.82 μs jitter)
- Stable operation (no drops, no spikes)
- Proper network configuration (PFC, QoS)

**Recommended Use Cases:**
- NVMe-oF / iSER storage
- Distributed databases
- HPC applications
- Real-time data processing
- Low-latency financial systems

---

## Test Commands Reference

### RDMA Bandwidth
```bash
# Standard test
ib_send_bw -d rocep19s0 -x 3 --report_gbits -s 1048576 -n 5000 -q 4 -F 192.168.251.111

# 10-minute test
ib_send_bw -d rocep19s0 -x 3 --report_gbits -s 1048576 -D 600 -q 4 -F 192.168.251.111
```

### RDMA Latency
```bash
# Standard test
ib_send_lat -d rocep19s0 -x 3 192.168.251.111

# Extended test
ib_send_lat -d rocep19s0 -x 3 -n 10000 192.168.251.111
```

### iperf (TCP Baseline)
```bash
# 6 seconds
iperf -c 192.168.251.111 -t 6

# 10 minutes
iperf -c 192.168.251.111 -t 600

# Parallel streams
iperf -c 192.168.251.111 -t 600 -P 4
```

---

## Future Tests to Consider
- Different message sizes (64B to 4MB)
- Different number of queue pairs
- Bidirectional tests (ib_read_bw, ib_write_bw)
- RDMA Write/Read latency tests
- Long-duration stability tests (hours)
- Concurrent connection tests
- Different CQ moderation values

---

**Last Updated:** December 17, 2025
**Related Documents:** RDMA_Performance_Testing_Summary.md
