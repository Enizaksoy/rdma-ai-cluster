# ECN and PFC Configuration - Session Notes
**Date:** December 30, 2025
**Session:** ECN Bit Verification and Docker Setup

---

## 1. Server Inventory - All 8 Ubuntu Servers

| Server | Management IP | RDMA Interface | RDMA Device | Notes |
|--------|---------------|----------------|-------------|-------|
| ubunturdma1 | 192.168.11.152 | ens224 | rocep19s0 | Docker 28.2.2 ✅ |
| ubunturdma2 | 192.168.11.153 | ens192 | rocep11s0 | Docker 28.2.2 ✅ |
| ubunturdma3 | 192.168.11.154 | ens224 | rocep19s0 | Docker 28.2.2 ✅ |
| ubunturdma4 | 192.168.11.155 | ens192 | rocep11s0 | Docker 28.2.2 ✅ |
| ubunturdma5 | 192.168.11.107 | ens192 | rocep11s0 | Docker 28.4.0 ✅ |
| ubunturdma6 | 192.168.12.51 | ens192 | rocep11s0 | Docker 28.2.2 ✅ |
| ubunturdma7 | 192.168.20.150 | ens192 | rocep11s0 | Docker 28.2.2 ✅ |
| ubunturdma8 | 192.168.30.94 | ens192 | rocep11s0 | Docker 28.4.0 ✅ |

**Credentials:** versa / <PASSWORD>

---

## 2. Network Configuration Summary

### Switch (Cisco Nexus - 192.168.50.229)
- **User:** admin / <PASSWORD>
- **MTU:** 9216 on all RDMA ports ✅
- **PFC:** Enabled on CoS 3 (for RoCE) ✅
- **ECN:** WRED with ECN marking configured ✅
- **RDMA Ports:** Ethernet1/1/1, 1/1/2, 1/2/1, 1/2/2

### Ubuntu Servers
- **MTU:** 9000 on all RDMA interfaces ✅
- **Safety margin:** 216 bytes (9216 - 9000)
- **Docker:** Installed on all 8 servers ✅

---

## 3. PFC (Priority Flow Control) Status

### Switch Configuration:
```bash
# PFC is enabled, not global flow control
# Only CoS 3 (RoCE) traffic gets PFC
policy-map type network-qos QOS_NETWORK
  class type network-qos c-nq3
    mtu 9216
    pause pfc-cos 3
```

**Key Understanding:**
- ❌ **Global Flow Control:** Disabled (intentional)
- ✅ **PFC (Priority Flow Control):** Enabled on CoS 3 only
- Internal interfaces show PFC activity (hundreds of thousands of frames)
- This is the CORRECT configuration for RoCE

### Verify PFC:
```bash
ssh admin@192.168.50.229
show interface priority-flow-control
```

---

## 4. ECN (Explicit Congestion Notification) Configuration

### Switch WRED ECN Policy:
```bash
policy-map type queuing RDMA_ECN_OUT
  class type queuing c-out-q3
    priority level 1
    random-detect threshold burst-optimized ecn  ← ECN ENABLED ✅
```

**Applied to interfaces:**
- Ethernet1/1/2 (verified) ✅
- Likely also on 1/1/1, 1/2/1, 1/2/2

### ECN Flow (Correct Understanding):
1. **Sender NIC:** Marks packets with **ECT bits** (ECN-Capable Transport)
   - Sets tos 0x2 or 0x1
2. **Switch:** Detects congestion, changes **ECT → CE** (Congestion Experienced)
   - Changes to tos 0x3
   - **THE SWITCH IS THE MARKER** ✅
3. **Receiver NIC:** Sees CE-marked packets
   - Generates CNP (Congestion Notification Packet) back to sender
   - Server stats: `np_ecn_marked_roce_packets` shows packets RECEIVED with CE
4. **Sender NIC:** Receives CNP, slows down transmission rate
   - Server stats: `rp_cnp_handled` shows CNP packets handled

### Check ECN Stats on Server:
```bash
ssh versa@192.168.11.152
rdma statistic show link rocep19s0/1 | grep -Ei "ce_pkts|cnp|ecn"
```

**Example output showing ECN working:**
```
rp_cnp_ignored: 0
rp_cnp_handled: 1,169,933        ← CNP packets handled (slowed down)
np_ecn_marked_roce_packets: 40,510,552  ← Packets marked by SWITCH with CE
np_cnp_sent: 30,458,349           ← CNP packets sent in response
```

---

## 5. Why Regular tcpdump Doesn't Work

**Problem:** RDMA uses **kernel bypass** - traffic never goes through Linux network stack

**Evidence:**
```bash
rdma statistic show: 48,014,728 rx_write_requests  ← RDMA traffic flowing
interface stats:     5,327 packets                 ← Only control traffic visible
```

**Solution:** Use **Mellanox tcpdump-rdma Docker container**

---

## 6. Capturing ECN Bits - Docker Method

### Prerequisites:
- Docker installed on all servers ✅
- RDMA traffic running

### Capture Command:
```bash
# On any server (example: ubunturdma1)
ssh versa@192.168.11.152

# Capture all UDP traffic (RoCEv2 uses UDP)
sudo docker run --rm \
  -v /dev/infiniband:/dev/infiniband \
  --net=host --privileged \
  mellanox/tcpdump-rdma \
  tcpdump -i rocep19s0 -c 100 -nn -v 'udp' | grep "tos 0x"
```

### What to Look For:
- **tos 0x0:** Not-ECT (no ECN capability)
- **tos 0x1:** ECT(1) (ECN-capable)
- **tos 0x2:** ECT(0) (ECN-capable) ← **Sent by sender**
- **tos 0x3:** CE (Congestion Experienced) ← **Marked by SWITCH!**

### Proof of Switch ECN Marking:
If **sender shows tos 0x2** and **receiver shows tos 0x3**, this PROVES the switch changed ECT → CE!

---

## 7. Monitoring Commands Reference

### ESXi Host Monitoring:
```bash
# Real-time NIC stats
ssh root@192.168.50.152
watch esxcli network nic stats get -n vmnic3

# Pause frame counters
watch vsish -e cat /net/pNics/vmnic3/stats | grep -i pause

# DCB/PFC status
esxcli network nic dcb status get -n vmnic3
```

### Switch Monitoring:
```bash
ssh admin@192.168.50.229

# PFC statistics
show interface priority-flow-control

# Flow control stats
show interface flowcontrol

# MMU drops (should be minimal with PFC working)
show queuing interface ethernet1/1/2 | include "Ingress MMU"

# ECN policy verification
show policy-map interface ethernet1/1/2 type queuing
```

### Ubuntu Server Monitoring:
```bash
ssh versa@192.168.11.152

# RDMA statistics (shows ECN/CNP activity)
rdma statistic show link rocep19s0/1 | grep -Ei "cnp|ecn"

# Watch RDMA stats in real-time
watch -n 1 'rdma statistic show link rocep19s0/1 | grep -E "rx_write|cnp|ecn"'

# Check MTU
ip link show ens224 | grep mtu
```

---

## 8. Key Learnings from This Session

### ECN Terminology Correction:
- **Sender:** Sets ECT bits (ECN-capable)
- **Switch (Network):** Marks ECT → CE when congested ← **THE MARKER**
- **Receiver:** Sees CE, sends CNP back
- **Sender:** Receives CNP, reduces rate

### NIC Statistics Interpretation:
- `np_ecn_marked_roce_packets` = Packets **received** with CE bits (marked by switch)
- `np_cnp_sent` = CNP packets sent in response to CE-marked packets
- `rp_cnp_handled` = CNP packets received and acted upon (as sender)

### Why Switch ECN Counters Show 0:
- Switch WRED stats show drops, not markings
- `WRED Drop Pkts: 0` = Good! ECN is marking instead of dropping
- `WRED Non ECN Drop Pkts: 0` = All traffic is ECN-capable
- No direct "ECN marked packets" counter on Nexus switches
- **Proof of marking comes from server-side statistics showing millions of CE-marked packets**

---

## 9. Docker Installation (Completed)

### Script Location:
`/mnt/c/Users/eniza/Documents/claudechats/install_docker_all_servers.sh`

### Manual Installation (if needed):
```bash
ssh versa@<server-ip>
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker versa
```

---

## 10. Files Created This Session

| File | Purpose |
|------|---------|
| `ECN_AND_PFC_SESSION_NOTES.md` | This document |
| `install_docker_all_servers.sh` | Docker installation script |
| `capture_ecn_all_servers.sh` | ECN capture script (to be run) |
| `PFC_SUCCESS_SUMMARY.md` | Previous PFC configuration summary |

---

## 11. Next Steps - ECN Bit Capture

1. ✅ Docker installed on all 8 servers
2. ⏳ Capture ECN bits during RDMA traffic
3. ⏳ Compare sender vs receiver TOS values
4. ⏳ Prove switch is doing ECN marking (ECT → CE)

---

## 12. Quick Reference Commands

### Check if RDMA traffic is flowing:
```bash
ssh versa@192.168.11.152
rdma statistic show link rocep19s0/1 | grep rx_write_requests
```

### Capture ECN bits (with Docker):
```bash
sudo docker run --rm -v /dev/infiniband:/dev/infiniband --net=host --privileged \
  mellanox/tcpdump-rdma tcpdump -i rocep19s0 -c 100 -nn -v 'udp' | grep "tos 0x"
```

### Check switch PFC activity:
```bash
ssh admin@192.168.50.229
show interface priority-flow-control | include -A 1 "ii1/1"
```

---

## 13. Important Notes

- **MTU:** Switch=9216, Servers=9000 (216 byte safety margin) ✅
- **PFC Mode:** Priority-based (CoS 3 only), not global flow control ✅
- **ECN:** Configured on switch WRED, working at NIC level ✅
- **Kernel Bypass:** Regular tcpdump can't see RDMA traffic - use Docker container
- **Server IPs:** Servers 5-8 are on different subnets (not all on 192.168.11.x)

---

**End of Session Notes**
