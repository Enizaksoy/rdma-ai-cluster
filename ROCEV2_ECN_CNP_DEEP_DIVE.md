# RoCEv2 ECN & CNP Deep Dive
## Understanding Congestion Control in Lossless RDMA Networks

[![CCIE](https://img.shields.io/badge/CCIE-23970-blue)](https://www.cisco.com/c/en/us/training-events/training-certifications/certifications/expert.html)
[![RoCEv2](https://img.shields.io/badge/Protocol-RoCEv2-green)](https://en.wikipedia.org/wiki/RDMA_over_Converged_Ethernet)
[![DCQCN](https://img.shields.io/badge/Algorithm-DCQCN-orange)](https://conferences.sigcomm.org/sigcomm/2015/pdf/papers/p523.pdf)

---

## Overview

This document provides a deep-dive analysis of **ECN (Explicit Congestion Notification)** and **CNP (Congestion Notification Packet)** in RoCEv2 networks, based on real packet captures from an 8-node RDMA AI cluster.

**What you'll learn:**
- How ECN marks packets during congestion
- How CNP packets trigger rate reduction
- How DCQCN algorithm maintains lossless operation
- Real packet analysis with Wireshark

---

## Table of Contents

- [Why This Matters](#why-this-matters)
- [The Three-Layer Congestion Control](#the-three-layer-congestion-control)
- [ECN Deep Dive](#ecn-deep-dive)
- [CNP Deep Dive](#cnp-deep-dive)
- [Real Packet Analysis](#real-packet-analysis)
- [Lab Results](#lab-results)
- [Wireshark Filters](#wireshark-filters)
- [References](#references)

---

## Why This Matters

Modern AI/ML training requires **lossless networking** for GPU-to-GPU communication:

```
Traditional TCP:                    RDMA with DCQCN:
┌─────────────────┐                ┌─────────────────┐
│ Packet dropped  │                │ ECN marks packet│
│ TCP retransmit  │                │ CNP sent back   │
│ ~1000x latency  │                │ Rate reduced    │
│ Training stalls │                │ Zero loss!      │
└─────────────────┘                └─────────────────┘
```

**Key Statistics from Production AI Clusters:**
- RDMA achieves **2x bandwidth** over TCP
- Latency reduced by **91%** (161μs → 14μs)
- Packet drops reduced by **96%**

---

## The Three-Layer Congestion Control

```
┌─────────────────────────────────────────────────────────────┐
│                    DCQCN Architecture                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Layer 3: DCQCN (Transport)                                 │
│  ├── CNP processing at NIC                                  │
│  ├── Per-flow rate limiting                                 │
│  └── Dynamic rate adjustment                                │
│                                                              │
│  Layer 2: ECN (Network)                                     │
│  ├── Switch marks packets (CE bit)                          │
│  ├── Early congestion signal                                │
│  └── Before buffers overflow                                │
│                                                              │
│  Layer 1: PFC (Link)                                        │
│  ├── Pause frames when buffers full                         │
│  ├── Last resort protection                                 │
│  └── Prevents packet drops                                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Goal: ECN + DCQCN prevent congestion BEFORE PFC is needed
```

---

## ECN Deep Dive

### What is ECN?

ECN (Explicit Congestion Notification) is an IP-layer mechanism that allows switches to **mark packets** instead of dropping them.

### ECN Bits in IP Header

```
IP TOS Byte (8 bits):
┌─────────────────────────────────────────┐
│ 7   6   5   4   3   2 │ 1   0          │
│       DSCP (6 bits)   │ ECN (2 bits)   │
└─────────────────────────────────────────┘
```

### ECN Values

| Value | Binary | Name | Meaning |
|-------|--------|------|---------|
| 0 | 00 | Not-ECT | Not ECN capable |
| 1 | 01 | ECT(1) | ECN capable |
| 2 | 10 | ECT(0) | ECN capable (default for RoCE) |
| **3** | **11** | **CE** | **Congestion Experienced** |

### How ECN Works

```
Step 1: Sender marks packet as ECN-capable
        ┌─────────┐
        │ Sender  │ ──── ECN=10 (ECT) ────►
        └─────────┘

Step 2: Switch detects congestion, marks CE
        ┌─────────┐
        │ Switch  │  Queue > threshold?
        │         │  Yes → Change ECN to 11 (CE)
        └─────────┘

Step 3: Receiver sees CE, generates CNP
        ┌──────────┐
        │ Receiver │  ECN=11 detected!
        │   NIC    │  Generate CNP packet
        └──────────┘
```

### Real ECN Example from Capture

**Normal Packet (No Congestion):**
```
Frame 1: RDMA Write
    IP Header:
        Differentiated Services Field: 0x02
            0000 00.. = DSCP: Default (0)
            .... ..10 = ECN: ECT(0)  ◄── ECN CAPABLE, NO CONGESTION
```

**Congested Packet (CE Marked):**
```
Frame 48: RDMA Write (same flow, 0.5ms later)
    IP Header:
        Differentiated Services Field: 0x03
            0000 00.. = DSCP: Default (0)
            .... ..11 = ECN: CE  ◄── CONGESTION EXPERIENCED!
```

---

## CNP Deep Dive

### What is CNP?

CNP (Congestion Notification Packet) is a special RoCEv2 packet that tells the sender to **slow down**.

**Key Facts:**
- Generated by **receiver NIC** (not application)
- Sent when receiver sees **CE-marked packets**
- Contains **QP number** to identify which flow to slow
- Marked with **DSCP 48** for high priority

### CNP Packet Structure

```
┌────────────────────────────────────────────────────┐
│ Ethernet Header (14 bytes)                         │
│   Src: Receiver MAC                                │
│   Dst: Sender MAC                                  │
├────────────────────────────────────────────────────┤
│ IP Header (20 bytes)                               │
│   Src: Receiver IP                                 │
│   Dst: Sender IP                                   │
│   DSCP: 48 (CS6) ◄── HIGH PRIORITY                │
│   ECN: ECT(0)                                      │
├────────────────────────────────────────────────────┤
│ UDP Header (8 bytes)                               │
│   Src Port: 0 ◄── SPECIAL CNP SIGNATURE           │
│   Dst Port: 4791 (RoCEv2)                          │
├────────────────────────────────────────────────────┤
│ InfiniBand BTH (12 bytes)                          │
│   OpCode: 0x81 (129) ◄── CNP IDENTIFIER           │
│   Dest QP: 0x000d1e ◄── WHICH FLOW TO SLOW DOWN   │
│   PSN: 0                                           │
├────────────────────────────────────────────────────┤
│ CNP Payload (16 bytes)                             │
│   Reserved fields                                  │
├────────────────────────────────────────────────────┤
│ ICRC (4 bytes)                                     │
└────────────────────────────────────────────────────┘
Total: 74 bytes (minimal overhead)
```

### Why CNP Uses DSCP 48

```
Switch Queue Priority:

┌─────────────────────────────────────────────────────┐
│ Queue 7 (Strict Priority) │ CNP Packets (DSCP 48)  │
│ ─────────────────────────►│ ALWAYS FIRST OUT       │
├───────────────────────────┼────────────────────────┤
│ Queue 3 (Bandwidth)       │ RDMA Data (DSCP 0/24)  │
│                           │ Normal queuing         │
├───────────────────────────┼────────────────────────┤
│ Queue 0 (Best Effort)     │ Other traffic          │
└─────────────────────────────────────────────────────┘

CNP must arrive FAST - if delayed, sender keeps flooding!
```

### Real CNP Example from Capture

```
Frame 42818: CNP Packet (74 bytes)

Ethernet II
    Src: 00:50:56:af:0d:ec
    Dst: 00:50:56:af:39:dc

Internet Protocol Version 4
    Src: 192.168.250.114 (Receiver sending CNP back)
    Dst: 192.168.250.117 (Original sender)

    Differentiated Services Field: 0xc2
        1100 00.. = DSCP: CS6 (48) ◄── HIGH PRIORITY
        .... ..10 = ECN: ECT(0)

User Datagram Protocol
    Src Port: 0 ◄── CNP SIGNATURE
    Dst Port: 4791

InfiniBand BTH
    Opcode: 129 (0x81) ◄── CNP OPCODE
    Dest QP: 0x000d1e ◄── FLOW TO SLOW DOWN
    PSN: 0
```

---

## Real Packet Analysis

### Complete DCQCN Flow from Capture

```
Timeline (from actual pcap):

T=0.000ms    Frame 1:    Normal RDMA Write, ECN=2 (ECT)
             │
T=0.278ms    Frame 26:   RDMA Write First, ECN=2 (ECT)
             │           Starting 64KB transfer
             │
T=0.517ms    Frame 48:   RDMA Write Middle, ECN=3 (CE) ◄── FIRST CONGESTION!
             │           Switch marked this packet
             │
T=0.587ms    Frame 55:   RDMA Write First, ECN=3 (CE)
             │           Congestion continues
             │
             ... (more CE-marked packets)
             │
T=196.7ms    Frame 42818: CNP generated!
             │            DSCP=48, OpCode=0x81
             │            Dest QP=0x000d1e
             │            "Slow down QP 0x000d1e!"
             │
             ▼
             Sender NIC receives CNP
             Rate reduced for QP 0x000d1e
```

### Packet Comparison Table

| Field | Normal (Frame 1) | CE Marked (Frame 48) | CNP (Frame 42818) |
|-------|------------------|---------------------|-------------------|
| **Size** | 62 bytes | 4154 bytes | 74 bytes |
| **TOS Byte** | 0x02 | 0x03 | 0xC2 |
| **DSCP** | 0 | 0 | **48** |
| **ECN** | 2 (ECT) | **3 (CE)** | 2 (ECT) |
| **OpCode** | 17 (ACK) | 7 (Write Mid) | **129 (CNP)** |
| **Direction** | A → B | A → B | A → B (feedback) |

---

## Lab Results

### Capture Statistics

```
════════════════════════════════════════════════════
  Capture File: rdma_ecn.pcap
  Duration: 4.796 seconds
  Total Packets: 808,992
  Total Bytes: 3.08 GB
  Average Rate: ~5.1 Gbps
════════════════════════════════════════════════════
```

### ECN Distribution

```
ECN State Distribution:

ECT(0) - Normal     ████████████████████████████████████ 687,671 (85%)
CE - Congestion     ██████                               121,321 (15%)
```

### DSCP Distribution

```
DSCP Distribution:

DSCP 0 (Default)    ████████████████████████████████████ 807,037 (99.8%)
DSCP 48 (CNP)       █                                      1,955 (0.2%)
```

### Key Findings

| Metric | Value | Analysis |
|--------|-------|----------|
| CE Rate | 15% | Moderate congestion during test |
| CNP Count | 1,955 | Active DCQCN operation |
| CE:CNP Ratio | 62:1 | Efficient - one CNP covers many CE packets |
| First CE | 0.5ms | Congestion detected quickly |
| CNP Response | ~196ms | Feedback loop active |

---

## Wireshark Filters

### Essential Filters

```bash
# All RoCEv2 traffic
udp.port == 4791

# ECN Congestion Experienced (CE)
ip.dsfield.ecn == 3

# CNP packets (DSCP 48)
ip.dsfield.dscp == 48

# CNP by OpCode
infiniband.bth.opcode == 129

# Specific QP traffic
infiniband.bth.dstqp == 0x000d1d
```

### Analysis Filters

```bash
# All congestion indicators
(ip.dsfield.ecn == 3) || (ip.dsfield.dscp == 48)

# RDMA Write operations
(infiniband.bth.opcode >= 6) && (infiniband.bth.opcode <= 8)

# ACK packets
infiniband.bth.opcode == 17
```

### tshark Commands

```bash
# Count ECN states
tshark -r capture.pcap -T fields -e ip.dsfield.ecn | sort | uniq -c

# Count DSCP values
tshark -r capture.pcap -T fields -e ip.dsfield.dscp | sort | uniq -c

# List CE-marked packets
tshark -r capture.pcap -Y "ip.dsfield.ecn == 3" -c 10

# List CNP packets
tshark -r capture.pcap -Y "ip.dsfield.dscp == 48" -c 10
```

---

## DSCP Marking: Who Does What?

### Important Distinction

| Traffic Type | Who Marks DSCP | How | Default |
|-------------|----------------|-----|---------|
| **RDMA Data** | Source NIC | Manual config | 0 (none) |
| **CNP** | Source NIC | Automatic | 48 (always) |

### Why RDMA Data Often Has DSCP 0

```
RDMA Data Marking:
┌────────────────────────────────────────────┐
│ Application calls RDMA Write()             │
│              ↓                             │
│ NIC creates packet                         │
│ DSCP = configured_value                    │
│                                            │
│ If not configured → DSCP = 0 (default)     │
└────────────────────────────────────────────┘

CNP Marking:
┌────────────────────────────────────────────┐
│ NIC receives CE-marked packet              │
│              ↓                             │
│ NIC generates CNP automatically            │
│ DSCP = 48 (HARDCODED in firmware)          │
│                                            │
│ Cannot be changed!                         │
└────────────────────────────────────────────┘
```

### Configuration for Proper DSCP Marking

```bash
# ConnectX NIC - Set DSCP 24 for RDMA data
echo 96 > /sys/kernel/config/rdma_cm/mlx5_0/ports/1/default_roce_tos
# Note: TOS = DSCP << 2, so DSCP 24 = TOS 96
```

---

## Summary

### Key Takeaways

1. **ECN signals congestion** by changing ECN bits from 2 (ECT) to 3 (CE)
2. **CNP is a real packet** - not just a header flag
3. **CNP contains QP number** - sender knows exactly which flow to slow
4. **DSCP 48 ensures CNP priority** - feedback must arrive fast
5. **Rate limiting happens at sender NIC** - not at switch

### The Complete Picture

```
┌─────────────────────────────────────────────────────────────────┐
│                      DCQCN Operation                             │
│                                                                  │
│  Sender                    Switch                    Receiver   │
│    │                         │                          │        │
│    │ ── RDMA Data (ECN=2) ──►│                          │        │
│    │                         │                          │        │
│    │                    [Queue fills]                   │        │
│    │                    [Mark ECN=3]                    │        │
│    │                         │                          │        │
│    │                         │── Data (ECN=3) ─────────►│        │
│    │                         │                          │        │
│    │                         │              [See CE mark]│        │
│    │                         │              [Generate CNP]       │
│    │                         │                          │        │
│    │◄─── CNP (DSCP 48) ──────│◄─────────────────────────│        │
│    │     OpCode 0x81         │     Strict Priority      │        │
│    │     QP=0x000d1e         │                          │        │
│    │                         │                          │        │
│ [Reduce rate                 │                          │        │
│  for QP 0x000d1e]            │                          │        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## References

- [DCQCN Paper (SIGCOMM 2015)](https://conferences.sigcomm.org/sigcomm/2015/pdf/papers/p523.pdf)
- [RFC 3168 - ECN](https://tools.ietf.org/html/rfc3168)
- [RoCEv2 Specification](https://cw.infinibandta.org/document/dl/7781)
- [Mellanox DCQCN Configuration Guide](https://docs.nvidia.com/networking/)

---

## Author

**Eniz Aksoy**
- CCIE Routing & Switching #23970
- Senior Network Architect | AI/ML Infrastructure
- [LinkedIn](https://linkedin.com/in/enizaksoy)
- [GitHub](https://github.com/Enizaksoy)

---

*Analysis based on live packet captures from 8-node RDMA AI cluster - January 2026*
