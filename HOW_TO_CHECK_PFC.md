# How to Check PFC/Pause Frames at All Levels

## 1. ESXi Host Level

### Check Pause Frame Statistics:

```bash
# SSH to ESXi host
ssh root@192.168.50.152

# Method 1: Basic stats (may not show pause frames)
esxcli network nic stats get -n vmnic3 | grep -i pause
esxcli network nic stats get -n vmnic4 | grep -i pause

# Method 2: Detailed pause counters (BEST METHOD)
vsish -e cat /net/pNics/vmnic3/stats | grep -i pause
vsish -e cat /net/pNics/vmnic4/stats | grep -i pause
```

### Key Counters to Watch:

```
rxPauseCtrlPhy:     Number of pause frames RECEIVED from switch
txPauseCtrlPhy:     Number of pause frames SENT to switch
rx_global_pause:    Global pause frames received
tx_global_pause:    Global pause frames transmitted
```

### Real-Time Monitoring:

```bash
# Watch pause frames update every 1 second
watch -n 1 "vsish -e cat /net/pNics/vmnic3/stats | grep pause"
```

---

## 2. Ubuntu Server Level (Guest OS)

### Check Interface Statistics:

```bash
# SSH to Ubuntu server
ssh versa@192.168.11.152

# Check pause frame statistics on RDMA interface
sudo ethtool -S ens224 | grep -i 'pause\|pfc'
sudo ethtool -S ens192 | grep -i 'pause\|pfc'

# Check pause parameters
sudo ethtool -a ens224
sudo ethtool -a ens192

# Check LLDP PFC configuration
sudo lldptool -t -i ens224 -V PFC
sudo lldptool -t -i ens192 -V PFC
```

### Expected Output (if working):

```
Pause parameters for ens224:
Autonegotiate:  off
RX:             on    <-- Should be "on" if PFC working
TX:             on    <-- Should be "on" if PFC working
```

---

## 3. Cisco Switch Level

### Check PFC Status:

```bash
# SSH to switch
ssh admin@192.168.50.229

# Check PFC on specific ports
show interface ethernet1/2/2 priority-flow-control
show interface ethernet1/2/1 priority-flow-control
show interface ethernet1/1/1 priority-flow-control
show interface ethernet1/1/2 priority-flow-control

# Check queue statistics and drops
show queuing interface ethernet1/2/2
show queuing interface ethernet1/2/1
```

### Key Metrics:

```
Port               Mode  Oper(VL)  RxPPP  TxPPP
Ethernet1/2/2      On    On (8)    1234   5678

RxPPP: Pause frames RECEIVED from servers (should be > 0 during traffic)
TxPPP: Pause frames SENT to servers (should be > 0 during congestion)
```

### Check for MMU Drops:

```bash
show queuing interface ethernet1/2/2 | include "MMU Drop"

# Should show:
Ingress MMU Drop Pkts: 0 (or minimal)
```

---

## 4. Complete Verification Workflow

### Step 1: Check Configuration

```bash
# On ESXi
esxcli network nic pauseParams list | grep -E 'vmnic3|vmnic4'
# Should show: Pause RX=true, TX=true

# On Ubuntu
sudo ethtool -a ens224
# Should show: RX=on or off (depends on driver support)

# On Switch
show running-config | include priority-flow
# Should show PFC enabled on interfaces
```

### Step 2: Run Traffic Test

```bash
# From your Windows/WSL machine
bash saturate_cross_esxi.sh 60
```

### Step 3: Monitor During Traffic

**Terminal 1 - ESXi Host 1:**
```bash
ssh root@192.168.50.152
watch -n 1 "vsish -e cat /net/pNics/vmnic3/stats | grep pause"
```

**Terminal 2 - Cisco Switch:**
```bash
ssh admin@192.168.50.229
# Keep running this command during traffic:
show interface ethernet1/2/2 priority-flow-control
```

**Terminal 3 - Traffic Generator:**
```bash
bash saturate_cross_esxi.sh 60
```

### Step 4: Verify Results

**If PFC is working correctly:**
- ✅ ESXi: txPauseCtrlPhy > 0 (servers sending pause)
- ✅ ESXi: rxPauseCtrlPhy > 0 (servers receiving pause)
- ✅ Switch: RxPPP > 0 (switch receiving pause from servers)
- ✅ Switch: TxPPP > 0 (switch sending pause to servers)
- ✅ Switch: MMU drops = 0 or minimal

**If PFC is NOT working:**
- ❌ All counters remain at 0
- ❌ High MMU drops on switch
- ❌ Packet loss during high traffic

---

## 5. Troubleshooting

### If Pause Frames = 0:

1. **Check traffic is using correct interfaces:**
   ```bash
   # On Ubuntu servers during traffic
   ip -s link show ens224  # Should show high RX/TX counters
   ```

2. **Check QoS/Priority mapping:**
   - RDMA traffic should be marked with DSCP 26 or CoS 3
   - Switch must map this to PFC-enabled priority

3. **Verify both ESXi hosts configured:**
   - Host 1: vmnic3, vmnic4
   - Host 2: vmnic5, vmnic6

4. **Check for VLAN tagging:**
   - PFC works at Layer 2
   - Must be on same VLAN for L2 PFC

### If MMU Drops Still Occur:

1. **Check PFC priority configuration:**
   ```bash
   # On switch
   show policy-map interface ethernet1/2/2
   # Verify RDMA traffic is in QoS group 3
   ```

2. **Adjust buffer/threshold settings:**
   - May need to tune ingress buffer thresholds
   - May need to adjust PFC xon/xoff thresholds

---

## 6. Quick Reference Commands

### ESXi (Best command):
```bash
vsish -e cat /net/pNics/vmnic3/stats | grep pause
```

### Ubuntu:
```bash
sudo ethtool -S ens224 | grep -i pause
```

### Cisco Switch:
```bash
show interface ethernet1/2/2 priority-flow-control
```

### Monitor All at Once:
```bash
bash monitor_pfc_all_levels.sh 30
```

---

## 7. Expected Values During Heavy Traffic

### Light Traffic (< 1 Gbps):
- Pause frames should be 0 or minimal
- No congestion, no need for flow control

### Heavy Traffic (> 8 Gbps):
- ESXi txPauseCtrlPhy: 100s - 1000s
- Switch RxPPP: 100s - 1000s
- Switch TxPPP: 100s - 1000s
- MMU Drops: 0 (pause prevents drops)

### Saturated Link (> 10 Gbps attempted):
- Pause frames should be very high (10,000+)
- Traffic regulated by PFC
- No packet loss

