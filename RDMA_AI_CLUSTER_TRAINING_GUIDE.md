# RDMA AI Cluster Training Guide
## Packet Analysis and Protocol Deep Dive

**Author:** Eniz Aksoy, CCIE #23970
**Date:** January 11, 2026
**Lab Environment:** 8-Node RDMA Cluster with Mellanox ConnectX NICs
**Capture File:** rdma_ecn.pcap (3.08 GB, 808,992 packets)

---

## Table of Contents

1. [Lab Environment Overview](#lab-environment-overview)
2. [Capture Statistics](#capture-statistics)
3. [RoCEv2 Packet Structure](#rocev2-packet-structure)
4. [Packet Analysis - Real Examples](#packet-analysis---real-examples)
5. [ECN States Explained](#ecn-states-explained)
6. [DCQCN in Action](#dcqcn-in-action)
7. [Wireshark Filters Reference](#wireshark-filters-reference)
8. [Key Takeaways](#key-takeaways)

---

## Lab Environment Overview

### Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│                    RDMA Test Environment                     │
│                                                              │
│   Host A (192.168.250.114)        Host B (192.168.250.117)  │
│   ┌─────────────────────┐        ┌─────────────────────┐    │
│   │  VMware VM          │        │  VMware VM          │    │
│   │  MAC: 00:50:56:     │        │  MAC: 00:50:56:     │    │
│   │       af:0d:ec      │        │       af:39:dc      │    │
│   │                     │        │                     │    │
│   │  ConnectX NIC       │        │  ConnectX NIC       │    │
│   │  (SR-IOV VF)        │        │  (SR-IOV VF)        │    │
│   └──────────┬──────────┘        └──────────┬──────────┘    │
│              │                              │               │
│              │         10/25 Gbps           │               │
│              └──────────────┬───────────────┘               │
│                             │                               │
│                    ┌────────▼────────┐                      │
│                    │  Cisco Nexus    │                      │
│                    │  PFC + ECN      │                      │
│                    │  Enabled        │                      │
│                    └─────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

### Traffic Pattern

- **Bidirectional RDMA Write** operations between two hosts
- **Queue Pairs (QP):**
  - Host A → Host B: QP 0x000d1d, 0x000d1e
  - Host B → Host A: QP 0x00023e, 0x00023f
- **Protocol:** RoCEv2 (RDMA over Converged Ethernet v2)
- **UDP Port:** 4791

---

## Capture Statistics

### Overall Statistics

```
========================================
| IO Statistics                        |
|--------------------------------------|
| Duration: 4.796 secs                 |
| Total Frames: 808,992                |
| Total Bytes: 3,081,829,768           |
| Average Rate: ~5.1 Gbps              |
========================================
```

### ECN Distribution

| ECN State | Value | Count | Percentage | Meaning |
|-----------|-------|-------|------------|---------|
| ECT(0) | 2 (10) | 687,671 | 85% | ECN capable, no congestion |
| CE | 3 (11) | 121,321 | **15%** | Congestion Experienced |

### DSCP Distribution

| DSCP | Count | Traffic Type |
|------|-------|--------------|
| 0 (Default) | 807,037 | RDMA Data (not marked by NIC) |
| 48 (CS6) | 1,955 | CNP (Congestion Notification Packet) |

### Packet Types Observed

| Packet Type | OpCode | Description |
|-------------|--------|-------------|
| RC RDMA Write First | 6 | First fragment of RDMA Write |
| RC RDMA Write Middle | 7 | Middle fragment |
| RC RDMA Write Last | 8 | Last fragment |
| RC Acknowledge | 17 | ACK response |
| CNP | 129 (0x81) | Congestion Notification |

---

## RoCEv2 Packet Structure

### Layer Structure

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Ethernet II                                        │
│   ├── Destination MAC (6 bytes)                             │
│   ├── Source MAC (6 bytes)                                  │
│   └── EtherType: 0x0800 (IPv4)                              │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: IPv4                                               │
│   ├── Version/IHL (1 byte)                                  │
│   ├── DSCP + ECN (1 byte) ◄── KEY FOR QoS                  │
│   ├── Total Length (2 bytes)                                │
│   ├── Identification, Flags, Fragment (4 bytes)             │
│   ├── TTL (1 byte)                                          │
│   ├── Protocol: 17 (UDP)                                    │
│   ├── Header Checksum (2 bytes)                             │
│   ├── Source IP (4 bytes)                                   │
│   └── Destination IP (4 bytes)                              │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: UDP                                                │
│   ├── Source Port (2 bytes)                                 │
│   ├── Destination Port: 4791 (RoCEv2)                       │
│   ├── Length (2 bytes)                                      │
│   └── Checksum (2 bytes, often 0x0000)                      │
├─────────────────────────────────────────────────────────────┤
│ InfiniBand: BTH (Base Transport Header)                     │
│   ├── OpCode (1 byte) ◄── OPERATION TYPE                   │
│   ├── SE/M/Pad/HeaderVer (1 byte)                           │
│   ├── Partition Key (2 bytes)                               │
│   ├── Reserved (1 byte)                                     │
│   ├── Destination QP (3 bytes) ◄── FLOW IDENTIFIER         │
│   ├── A/Reserved (1 byte)                                   │
│   └── PSN - Packet Sequence Number (3 bytes)                │
├─────────────────────────────────────────────────────────────┤
│ Extended Headers (varies by OpCode)                         │
│   ├── RETH: Virtual Address, Remote Key, DMA Length         │
│   └── AETH: Syndrome, MSN (for ACKs)                        │
├─────────────────────────────────────────────────────────────┤
│ Payload Data (up to 4096 bytes)                             │
├─────────────────────────────────────────────────────────────┤
│ ICRC - Invariant CRC (4 bytes)                              │
└─────────────────────────────────────────────────────────────┘
```

### DSCP + ECN Byte (IP TOS Field)

```
TOS Byte: 0x02 (Normal) or 0x03 (CE) or 0xC2 (CNP)

Bit Layout:
┌─────────────────────────────────────────┐
│ 7   6   5   4   3   2 │ 1   0          │
│       DSCP (6 bits)   │ ECN (2 bits)   │
└─────────────────────────────────────────┘

Examples:
  0x02 = 0000 0010 = DSCP 0  + ECN 2 (ECT(0)) - Normal
  0x03 = 0000 0011 = DSCP 0  + ECN 3 (CE)     - Congestion!
  0xC2 = 1100 0010 = DSCP 48 + ECN 2 (ECT(0)) - CNP
```

---

## Packet Analysis - Real Examples

### Example 1: RC Acknowledge Packet (Frame 1)

**Purpose:** Acknowledges received RDMA data

```
Frame 1: 62 bytes on wire
Arrival Time: Dec 30, 2025 17:04:27.155267000

Ethernet II
    Destination: 00:50:56:af:39:dc (VMware)
    Source: 00:50:56:af:0d:ec (VMware)
    Type: IPv4 (0x0800)

Internet Protocol Version 4
    Source: 192.168.250.114
    Destination: 192.168.250.117

    Differentiated Services Field: 0x02
        0000 00.. = DSCP: Default (0)
        .... ..10 = ECN: ECT(0) - ECN Capable ◄── NORMAL STATE

    Total Length: 48
    TTL: 64
    Protocol: UDP (17)

User Datagram Protocol
    Source Port: 53025
    Destination Port: 4791 (RoCEv2) ◄── RoCEv2 PORT
    Length: 28

InfiniBand - Base Transport Header
    Opcode: RC Acknowledge (17) ◄── ACK PACKET
    Partition Key: 65535
    Destination Queue Pair: 0x000d1e ◄── QP IDENTIFIER
    Packet Sequence Number: 4615966

AETH - ACK Extended Transport Header
    Syndrome: 0, Ack
        OpCode: Ack (0)
        Credit Count: 0
    Message Sequence Number: 945922

Invariant CRC: 0x8d64383d
```

**Key Points:**
- Small packet (62 bytes) - no payload, just acknowledgment
- ECN = 2 (ECT(0)) - Normal operation, ECN capable
- OpCode 17 = Acknowledge
- AETH contains MSN (Message Sequence Number)

---

### Example 2: RDMA Write First Packet (Frame 26)

**Purpose:** First fragment of a large RDMA Write operation

```
Frame 26: 4170 bytes on wire
Arrival Time: Dec 30, 2025 17:04:27.155545000

Ethernet II
    Destination: 00:50:56:af:39:dc
    Source: 00:50:56:af:0d:ec
    Type: IPv4 (0x0800)

Internet Protocol Version 4
    Source: 192.168.250.114
    Destination: 192.168.250.117

    Differentiated Services Field: 0x02
        0000 00.. = DSCP: Default (0)
        .... ..10 = ECN: ECT(0) ◄── STILL NORMAL

    Total Length: 4156
    TTL: 64
    Protocol: UDP (17)

User Datagram Protocol
    Source Port: 53027
    Destination Port: 4791
    Length: 4136

InfiniBand - Base Transport Header
    Opcode: RC RDMA WRITE First (6) ◄── FIRST FRAGMENT
    Partition Key: 65535
    Destination Queue Pair: 0x000d1d
    Packet Sequence Number: 12906524

RETH - RDMA Extended Transport Header ◄── ONLY IN "FIRST" PACKETS
    Virtual Address: 0x0000710e45036000 ◄── REMOTE MEMORY ADDRESS
    Remote Key: 0x000c0400 ◄── MEMORY REGISTRATION KEY
    DMA Length: 65536 (64 KB total transfer) ◄── TOTAL SIZE

Invariant CRC: 0x2642515f

Data (4096 bytes)
    0000  21 96 38 83 3c 62 66 41 a6 0d 42 23 b2 10 7f ec
    0010  88 6e 79 3f 61 7e 42 39 fd 43 95 81 db a0 40 fc
    ...
```

**Key Points:**
- Large packet (4170 bytes) - contains 4096 bytes of data
- OpCode 6 = RDMA Write First
- RETH header contains remote memory address and key
- DMA Length shows total transfer is 64KB (will be split into multiple packets)
- Subsequent "Middle" packets don't have RETH (saves bandwidth)

---

### Example 3: Congestion Experienced (CE) Packet (Frame 48)

**Purpose:** Switch marked this packet as experiencing congestion

```
Frame 48: 4154 bytes on wire
Arrival Time: Dec 30, 2025 17:04:27.155784000
Time since first frame: 517.000 microseconds ◄── ~0.5ms INTO CAPTURE

Ethernet II
    Destination: 00:50:56:af:39:dc
    Source: 00:50:56:af:0d:ec
    Type: IPv4 (0x0800)

Internet Protocol Version 4
    Source: 192.168.250.114
    Destination: 192.168.250.117

    Differentiated Services Field: 0x03 ◄── CHANGED FROM 0x02!
        0000 00.. = DSCP: Default (0)
        .... ..11 = ECN: Congestion Experienced (3) ◄── CE MARKING!

    Total Length: 4140
    TTL: 64
    Protocol: UDP (17)

User Datagram Protocol
    Source Port: 53027
    Destination Port: 4791
    Length: 4120

InfiniBand - Base Transport Header
    Opcode: RC RDMA WRITE Middle (7)
    Partition Key: 65535
    Destination Queue Pair: 0x000d1d
    Packet Sequence Number: 12906536

Invariant CRC: 0xb27e8727

Data (4096 bytes)
    0000  a9 28 08 8e 5c 54 0e 84 25 61 37 d1 12 75 b7 2b
    ...
```

**Key Points:**
- ECN changed from 0x02 to 0x03 (CE - Congestion Experienced)
- **Switch marked this packet** because queue depth exceeded threshold
- Receiver will see this CE mark and generate CNP
- This triggers DCQCN rate reduction at sender

**Visual Comparison:**

```
Normal packet (Frame 1):    TOS = 0x02 → ECN bits = 10 → ECT(0)
Congested packet (Frame 48): TOS = 0x03 → ECN bits = 11 → CE ◄── MARKED!
```

---

### Example 4: CNP - Congestion Notification Packet (Frame 42818)

**Purpose:** Tells sender to slow down - generated by receiver NIC

```
Frame 42818: 74 bytes on wire ◄── SMALL PACKET!
Arrival Time: Dec 30, 2025 17:04:27.351990000
Time since first frame: 196.723 milliseconds

Ethernet II
    Destination: 00:50:56:af:39:dc
    Source: 00:50:56:af:0d:ec
    Type: IPv4 (0x0800)

Internet Protocol Version 4
    Source: 192.168.250.114 ◄── RECEIVER SENDS CNP BACK
    Destination: 192.168.250.117 ◄── TO ORIGINAL SENDER

    Differentiated Services Field: 0xc2 ◄── DSCP 48!
        1100 00.. = DSCP: Class Selector 6 (48) ◄── HIGH PRIORITY
        .... ..10 = ECN: ECT(0) (2)

    Total Length: 60
    TTL: 64
    Protocol: UDP (17)

User Datagram Protocol
    Source Port: 0 ◄── SPECIAL: SOURCE PORT IS 0
    Destination Port: 4791
    Length: 40

InfiniBand - Base Transport Header
    Opcode: Unknown (129) ◄── 0x81 = CNP OPCODE
    Partition Key: 65535
    Reserved: 40
    Destination Queue Pair: 0x000d1e ◄── WHICH QP TO SLOW DOWN
    Packet Sequence Number: 0

CNP Payload: 00000000000000000000000000000000b0081c7f
```

**Key Points:**
- **DSCP 48 (CS6)** - High priority, goes to strict priority queue
- **OpCode 129 (0x81)** - CNP identifier
- **Dest QP 0x000d1e** - Tells sender which flow to slow down
- **Small packet (74 bytes)** - Minimal overhead
- **Source port 0** - Special CNP signature
- **Automatically generated** by receiver NIC when it sees CE-marked packets

---

## ECN States Explained

### ECN Bit Values

```
ECN Field (2 bits in IP header):

┌─────────────────────────────────────────────────────────────┐
│ Value │ Binary │ Name    │ Meaning                         │
├───────┼────────┼─────────┼─────────────────────────────────┤
│   0   │   00   │ Not-ECT │ Not ECN Capable Transport       │
│   1   │   01   │ ECT(1)  │ ECN Capable Transport (1)       │
│   2   │   10   │ ECT(0)  │ ECN Capable Transport (0)       │
│   3   │   11   │ CE      │ Congestion Experienced          │
└─────────────────────────────────────────────────────────────┘
```

### ECN State Transition

```
                    SENDER                           SWITCH                         RECEIVER
                      │                                │                                │
                      │  Packet with ECN=10 (ECT)      │                                │
                      │───────────────────────────────►│                                │
                      │                                │                                │
                      │                    ┌───────────┴───────────┐                   │
                      │                    │ Queue depth check:    │                   │
                      │                    │ > threshold?          │                   │
                      │                    └───────────┬───────────┘                   │
                      │                                │                                │
                      │                    ┌───────────┴───────────┐                   │
                      │                    │ YES: Mark ECN=11 (CE) │                   │
                      │                    │ NO:  Keep ECN=10      │                   │
                      │                    └───────────┬───────────┘                   │
                      │                                │                                │
                      │                                │  Packet delivered              │
                      │                                │───────────────────────────────►│
                      │                                │                                │
                      │                                │           ┌────────────────────┤
                      │                                │           │ Check ECN bits     │
                      │                                │           │ ECN=11? Generate   │
                      │                                │           │ CNP packet         │
                      │                                │           └────────────────────┤
                      │                                │                                │
                      │◄───────────────────────────────────────────────────────────────│
                      │                    CNP (DSCP 48, OpCode 0x81)                   │
                      │                                                                 │
          ┌───────────┴───────────┐                                                    │
          │ Receive CNP           │                                                    │
          │ Reduce rate for QP    │                                                    │
          │ specified in CNP      │                                                    │
          └───────────────────────┘                                                    │
```

### In Your Capture

```
Timeline Analysis:

Frame 1-47:     ECN = 2 (ECT(0))    Normal operation
                │
Frame 48:       ECN = 3 (CE)        ◄── First congestion mark! (~0.5ms)
                │
Frame 49-54:    Mix of ECT(0) and CE
                │
Frame 55:       ECN = 3 (CE)        Congestion continues
                │
...             │
                │
Frame 42818:    CNP generated       ◄── Receiver sends CNP (~197ms)
                DSCP = 48
                OpCode = 0x81
                Dest QP = 0x000d1e
```

---

## DCQCN in Action

### Rate Reduction Algorithm

```
When sender NIC receives CNP:

1. Identify flow (from Dest QP in CNP)
2. Apply DCQCN rate reduction:

   New_Rate = Current_Rate × (1 - g)

   Where g = configured reduction factor (typically 0.5)

   Example:
   Current Rate: 25 Gbps
   After CNP:    12.5 Gbps (50% reduction)

3. Start recovery timer
4. Gradually increase rate if no more CNPs received
```

### Your Capture Statistics

```
Total Packets:        808,992
CE Marked Packets:    121,321 (15%)
CNP Packets:          1,955

Ratio Analysis:
- CE to CNP ratio: 62:1
- One CNP responds to multiple CE-marked packets
- This is efficient - don't need CNP for every CE packet

Timeline:
- First CE mark: ~0.5ms into capture
- CNP packets: distributed throughout ~4.8 second capture
- Shows continuous congestion control adjustment
```

---

## Wireshark Filters Reference

### Basic Filters

```
# All RoCEv2 traffic
udp.port == 4791

# Specific source/destination
ip.src == 192.168.250.114 && udp.port == 4791
ip.dst == 192.168.250.117 && udp.port == 4791

# Specific QP
infiniband.bth.dstqp == 0x000d1d
```

### ECN Filters

```
# ECN Capable (normal)
ip.dsfield.ecn == 2

# Congestion Experienced (CE marked)
ip.dsfield.ecn == 3

# All ECN-capable traffic
ip.dsfield.ecn >= 1

# Compare: Show transition from normal to congested
(ip.dsfield.ecn == 2) || (ip.dsfield.ecn == 3)
```

### DSCP Filters

```
# Default DSCP (RDMA data)
ip.dsfield.dscp == 0

# CNP traffic (DSCP 48 / CS6)
ip.dsfield.dscp == 48

# By TOS byte
ip.dsfield == 0xc2  # CNP
ip.dsfield == 0x02  # Normal ECT(0)
ip.dsfield == 0x03  # CE marked
```

### Packet Type Filters

```
# RDMA Write operations
infiniband.bth.opcode == 6   # Write First
infiniband.bth.opcode == 7   # Write Middle
infiniband.bth.opcode == 8   # Write Last

# Acknowledge packets
infiniband.bth.opcode == 17

# CNP packets (may show as "Unknown 129")
infiniband.bth.opcode == 129
```

### Combined Filters for Analysis

```
# CE marked RDMA Write packets
(ip.dsfield.ecn == 3) && (udp.port == 4791)

# CNP packets only
(ip.dsfield.dscp == 48) && (udp.port == 4791)

# All congestion-related (CE + CNP)
(ip.dsfield.ecn == 3) || (ip.dsfield.dscp == 48)

# Traffic from specific host with congestion
ip.src == 192.168.250.114 && ip.dsfield.ecn == 3
```

### Statistics Commands (tshark)

```bash
# Count packets by ECN value
tshark -r file.pcap -T fields -e ip.dsfield.ecn | sort | uniq -c

# Count packets by DSCP
tshark -r file.pcap -T fields -e ip.dsfield.dscp | sort | uniq -c

# Show CE packets with timestamps
tshark -r file.pcap -Y "ip.dsfield.ecn == 3" -T fields \
  -e frame.number -e frame.time_relative -e ip.src -e ip.dst

# Count by OpCode
tshark -r file.pcap -T fields -e infiniband.bth.opcode | sort | uniq -c
```

---

## Key Takeaways

### 1. ECN Marking Flow

```
Sender (ECT) → Switch (marks CE if congested) → Receiver (sees CE, sends CNP) → Sender (slows down)
```

### 2. Packet Identification

| Field | Where | Purpose |
|-------|-------|---------|
| ECN bits | IP header (TOS byte) | Congestion signaling |
| DSCP | IP header (TOS byte) | QoS classification |
| OpCode | InfiniBand BTH | Operation type |
| Dest QP | InfiniBand BTH | Flow identification |
| UDP 4791 | UDP header | RoCEv2 identifier |

### 3. Critical Values to Remember

| Item | Value | Meaning |
|------|-------|---------|
| ECN = 2 | 0x02 | Normal, ECN capable |
| ECN = 3 | 0x03 | Congestion experienced |
| DSCP = 48 | 0xC0 | CNP priority |
| OpCode = 129 | 0x81 | CNP packet |
| UDP Port | 4791 | RoCEv2 |

### 4. Troubleshooting Checklist

- [ ] Are packets ECN-capable? (ECN = 1 or 2)
- [ ] Is switch marking CE? (ECN = 3 under load)
- [ ] Are CNPs being generated? (DSCP 48, OpCode 0x81)
- [ ] Is CNP reaching sender? (Check return path)
- [ ] Is rate reducing? (Monitor throughput after CNP)

### 5. Performance Indicators

| Metric | Good | Warning | Problem |
|--------|------|---------|---------|
| CE rate | < 5% | 5-15% | > 15% |
| CNP rate | Low | Medium | High continuous |
| PFC frames | Near 0 | Occasional | Frequent |

---

## Appendix: Raw Packet Hex Dumps

### Normal ACK Packet (Frame 1)

```
0000   00 50 56 af 39 dc 00 50 56 af 0d ec 08 00 45 02
0010   00 30 36 31 40 00 40 11 8e 50 c0 a8 fa 72 c0 a8
0020   fa 75 cf 21 12 b7 00 1c 00 00 11 60 ff ff 00 00
0030   0d 1e 00 46 6f 1e 00 00 e7 02 8d 64 38 3d
```

### CE Marked Packet (Frame 48) - Note TOS byte change

```
0000   00 50 56 af 39 dc 00 50 56 af 0d ec 08 00 45 03
                                                    ^^
                                              TOS = 0x03 (CE!)
```

### CNP Packet (Frame 42818)

```
0000   00 50 56 af 39 dc 00 50 56 af 0d ec 08 00 45 c2
                                                    ^^
                                              TOS = 0xC2 (DSCP 48)
0010   00 3c b8 c5 40 00 40 11 0a f0 c0 a8 fa 72 c0 a8
0020   fa 75 00 00 12 b7 00 28 00 00 81 60 ff ff 28 00
                                    ^^
                              OpCode = 0x81 (CNP)
0030   0d 1e 00 00 00 00 00 00 00 00 00 00 00 00 00 00
          ^^^^
    Dest QP = 0x000d1e
```

---

*Document generated from live packet captures - January 11, 2026*
*Lab Environment: Eniz Aksoy's 8-Node RDMA AI Cluster*
