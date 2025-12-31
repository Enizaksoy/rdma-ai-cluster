# PFC Configuration Summary

## Current Status

### ✅ What WAS Successfully Configured (Guest OS Level):

On all 8 servers, the following was successfully configured:

1. **lldpad installed and running**
2. **PFC enabled via lldptool on RDMA interfaces:**
   - `sudo lldptool -T -i <interface> -V PFC enableTx=yes`
   - `sudo lldptool -i <interface> -T -V PFC -c enabled=0,0,0,1,0,0,0,0`
   - `sudo lldptool set-lldp -i <interface> adminStatus=rxtx`

**Interfaces configured:**
- ubunturdma1: ens224 (192.168.251.111)
- ubunturdma2: ens192 (192.168.250.112)
- ubunturdma3: ens224 (192.168.251.113)
- ubunturdma4: ens192 (192.168.250.114)
- ubunturdma5: ens192 (192.168.250.115)
- ubunturdma6: ens192 (192.168.251.116)
- ubunturdma7: ens192 (192.168.250.117)
- ubunturdma8: ens192 (192.168.251.118)

### ❌ What CANNOT Be Configured (Guest OS Limitation):

**Hardware pause frames via ethtool:**
```bash
sudo ethtool -A ens192 rx on tx on
# Returns: "netlink error: Operation not supported"
```

**Why?** These are **virtual NICs in ESXi VMs**, not physical NICs. The hardware-level pause control must be configured at the ESXi host level, not inside the guest OS.

---

## Required: ESXi Host Configuration

For PFC to actually work, you MUST configure it on your ESXi hosts.

### Option 1: Via ESXi CLI (Recommended)

SSH to each ESXi host and run:

```bash
# List physical NICs
esxcli network nic list

# Check current pause parameters (for vmnic0, vmnic1, etc.)
esxcli network nic pauseParams list

# Enable PFC on physical NIC
esxcli network nic pauseParams set -n vmnic0 --rx-pause=true --tx-pause=true
esxcli network nic pauseParams set -n vmnic1 --rx-pause=true --tx-pause=true

# Verify
esxcli network nic pauseParams list
```

### Option 2: Via vCenter (GUI)

1. Log into vCenter
2. Navigate to: **Hosts and Clusters** → Select ESXi Host
3. Go to: **Configure** → **Networking** → **Physical Adapters**
4. Select the physical adapter (vmnic)
5. Click **Edit Settings**
6. Under **Advanced**, enable **Flow Control** or **Priority Flow Control**

### Option 3: Configure vSwitch/Distributed Switch

1. In vCenter, go to **Networking**
2. Select your **Distributed Switch**
3. Go to **Configure** → **Settings** → **Advanced**
4. Enable **Network I/O Control (NIOC)**
5. Configure **RDMA** traffic class with PFC enabled

---

## Verification Commands

### On Ubuntu Servers (Guest OS):

```bash
# Check LLDP/DCB PFC configuration
sudo lldptool -t -i ens192 -V PFC
sudo lldptool -t -i ens224 -V PFC

# Check interface status (will show RX:off TX:off due to VM limitation)
sudo ethtool -a ens192
sudo ethtool -a ens224

# Check RDMA interface statistics
sudo ethtool -S ens192 | grep -i 'pause\|pfc'
sudo ethtool -S ens224 | grep -i 'pause\|pfc'
```

### On ESXi Host:

```bash
# Check physical NIC pause configuration
esxcli network nic pauseParams list

# Check vSwitch configuration
esxcli network vswitch standard list
esxcli network vswitch dvs vmware list
```

### On Cisco Switch (Most Reliable):

```bash
ssh admin@192.168.50.229

# Check PFC status
show interface ethernet1/2/2 priority-flow-control
show interface ethernet1/2/1 priority-flow-control
show interface ethernet1/1/1 priority-flow-control
show interface ethernet1/1/2 priority-flow-control

# Check for pause frames during traffic
show queuing interface ethernet1/2/2

# Look for:
# - RxPPP > 0 (receiving pause frames from servers)
# - TxPPP > 0 (sending pause frames to servers)
# - Ingress MMU Drop Pkts should be 0 or minimal
```

---

## Current Problem

**Switch shows:**
```
RxPPP: 0   (NOT receiving pause from servers)
TxPPP: 0   (NOT sending pause to servers)
MMU Drops: 6,493,907 packets (~7 GB dropped)
```

**Root Cause:** PFC is not configured at the ESXi host/vSwitch level, so pause frames are never generated or honored by the physical NICs.

---

## Next Steps

1. **Configure PFC on ESXi hosts** (required)
2. **Run traffic test:**
   ```bash
   bash saturate_cross_esxi.sh 60
   ```
3. **Check switch during traffic:**
   ```bash
   ssh admin@192.168.50.229
   show interface ethernet1/2/2 priority-flow-control
   ```
4. **Verify:**
   - RxPPP > 0
   - TxPPP > 0
   - MMU drops = 0 or minimal

---

## ESXi Host Information Needed

To help you configure PFC on ESXi, please provide:

1. ESXi host IPs/names
2. Which vmnic (physical NIC) is connected to the switch?
3. Which vSwitch are the VMs using?
4. Are you using Standard vSwitch or Distributed vSwitch?

---

## Alternative: Test Without PFC (Not Recommended for Production)

If ESXi PFC configuration is not immediately available, you can test RDMA without lossless configuration, but you will experience:
- Packet drops (MMU drops on switch)
- Reduced performance
- Potential RDMA retransmissions
- Not suitable for production AI/ML workloads

Current testing already shows this: ~7GB of dropped data.

