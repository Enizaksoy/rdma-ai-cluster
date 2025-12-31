# RDMA Setup on Ubuntu 24 with SR-IOV - Complete Command Reference

## 1. VERIFY SR-IOV HARDWARE

### Check Mellanox NIC
```bash
lspci | grep -i mellanox
```

### Check RDMA Devices
```bash
ibv_devices
```

### Detailed Device Info
```bash
ibv_devinfo
```

---

## 2. INSTALL RDMA DRIVERS

### Update Package Manager
```bash
sudo apt update
```

### Install Core RDMA Packages
```bash
sudo apt install rdma-core ibverbs-utils ibverbs-providers libibverbs1
```

### Install Mellanox Drivers (For Mellanox NICs)
```bash
sudo apt install mlnx-ofed-kernel-modules mlnx-ethtool
```

### Verify Modules Loaded
```bash
lsmod | grep mlx
lsmod | grep rdma
```

---

## 3. CONFIGURE NETWORK INTERFACES

### Check Network Interfaces
```bash
ip link show
```

### Configure via Netplan

Edit netplan config:
```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

**Example Configuration for ens192:**
```yaml
network:
  version: 2
  ethernets:
    ens160:
      dhcp4: true
    ens192:
      addresses:
        - 192.168.250.201/24
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      routes:
        - to: 192.168.251.0/24
          via: 192.168.250.10
```

### Apply Configuration
```bash
sudo netplan apply
```

### Fix File Permissions
```bash
sudo chmod 600 /etc/netplan/00-installer-config.yaml
```

### Verify Interface is UP
```bash
ip addr show ens192
ip route show
```

---

## 4. SET HOSTNAME (Important for Fabric Formation)

### Check Current Hostname
```bash
hostname
```

### Change Hostname (on each server)
```bash
sudo hostnamectl set-hostname ubunturdma1
```

### Update /etc/hosts
```bash
sudo nano /etc/hosts
```
Add/modify:
```
127.0.0.1 ubunturdma1
```

### Reboot (Optional but recommended)
```bash
sudo reboot
```

---

## 5. INSTALL SUBNET MANAGER (OpenSM)

### Install OpenSM
```bash
sudo apt install opensm
```

### Start OpenSM Service
```bash
sudo systemctl start opensm
sudo systemctl enable opensm
```

### Check OpenSM Status
```bash
sudo systemctl status opensm
```

### Verify Subnet Manager is Running
```bash
sminfo
```

---

## 6. VERIFY RDMA DEVICE STATUS

### Check Device Details
```bash
ibv_devinfo -d mlx5_0
```

**Look for:**
- `state: PORT_ACTIVE (4)` ✓
- `sm_lid:` (non-zero value) ✓
- `port_lid:` (non-zero value) ✓

### Check All RDMA Devices
```bash
ibv_devinfo
```

### Check RDMA Link Status
```bash
rdma link show
```

---

## 7. DISABLE NETWORK OFFLOADS (For RoCE optimization)

### Disable TSO, GSO, GRO
```bash
sudo ethtool -K ens192 tso off gso off gro off
```

### Verify Offloads are Disabled
```bash
ethtool -k ens192 | grep -E "tso|gso|gro"
```

---

## 8. TEST RDMA CONNECTIVITY

### Install Performance Testing Tools
```bash
sudo apt install perftest
```

### Test Local RDMA (Same Server)
```bash
ib_send_bw -d mlx5_0 -i 1 127.0.0.1
```

### Test Between Two Servers

**On Server 1 (Start Server):**
```bash
ib_send_bw -d mlx5_0 -i 1
```

**On Server 2 (Connect as Client):**
```bash
ib_send_bw -d mlx5_0 -i 1 192.168.250.201
```

### Test RDMA Latency

**On Server 1:**
```bash
ib_read_lat -d mlx5_0 -i 1
```

**On Server 2:**
```bash
ib_read_lat -d mlx5_0 -i 1 192.168.250.201
```

### Test Bandwidth with Different Message Sizes
```bash
ib_send_bw -d mlx5_0 -i 1 192.168.250.201 -s 65536
```

---

## 9. VERIFY NETWORK CONNECTIVITY

### Ping Between Servers
```bash
ping 192.168.250.201
ping 192.168.250.202
```

### Check GID Configuration
```bash
ibv_devinfo -v | grep -A 5 "GID"
```

### Check Loaded Kernel Modules
```bash
lsmod | grep -E "rdma|infiniband|mlx"
```

---

## 10. TROUBLESHOOTING

### Check System Logs for RDMA Errors
```bash
sudo dmesg | tail -50 | grep -i rdma
sudo dmesg | tail -50 | grep -i error
```

### Check OpenSM Logs
```bash
sudo systemctl status opensm -l
```

### List All RDMA Resources
```bash
rdma resource show
```

### Check Network Interface Driver
```bash
ethtool -i ens192
```

### Verify RDMA Module is Loaded
```bash
lsmod | grep ib_umad
```

### Load Missing Modules (if needed)
```bash
sudo modprobe ib_umad
sudo modprobe ib_core
sudo modprobe rdma_cm
```

### Make Modules Persistent
```bash
echo "ib_umad" | sudo tee -a /etc/modules
echo "ib_core" | sudo tee -a /etc/modules
echo "rdma_cm" | sudo tee -a /etc/modules
```

---

## 11. QUICK VERIFICATION CHECKLIST

Run these on both servers to verify full setup:

```bash
# 1. Check hostname is different on each server
hostname

# 2. Check RDMA device detected
ibv_devices

# 3. Check device is PORT_ACTIVE
ibv_devinfo -d mlx5_0 | grep state

# 4. Check port has valid LID
ibv_devinfo -d mlx5_0 | grep -E "sm_lid|port_lid"

# 5. Check network connectivity
ping 192.168.250.201

# 6. Check RDMA link is UP
rdma link show

# 7. Verify OpenSM running
sudo systemctl status opensm
```

---

## EXPECTED OUTPUT

### Successful Device Status
```
state: PORT_ACTIVE (4)
sm_lid: 1                    # Non-zero value
port_lid: 1                  # Non-zero value
```

### Successful Bandwidth Test
```
#bytes     #iterations    BW peak[MB/sec]    BW average[MB/sec]
65536      1000             50000+             50000+              (For 100G NICs)
```

### Successful RDMA Link
```
link mlx5_0/1 state ACTIVE physical_state LINK_UP
```

---

## PERFORMANCE EXPECTATIONS

| Setup Type | Expected Bandwidth |
|---|---|
| Virtual RoCE (rocep11s0) | ~1-6 GB/sec |
| SR-IOV with Mellanox 25G | ~3-4 GB/sec |
| SR-IOV with Mellanox 100G | ~12+ GB/sec |
| Physical Mellanox 100G | ~12+ GB/sec |

---

## COMMON ISSUES & FIXES

### Issue: PORT_DOWN
**Solution:** Install OpenSM and ensure OpenSM service is running
```bash
sudo systemctl start opensm
sudo systemctl status opensm
```

### Issue: sm_lid = 0
**Solution:** Wait 30 seconds for OpenSM to discover devices, then recheck
```bash
sleep 30
ibv_devinfo -d mlx5_0
```

### Issue: Failed to modify QP
**Solution:** Ensure both servers are on same subnet or reachable via gateway
```bash
ping <remote_server_ip>
```

### Issue: Protocol not supported
**Solution:** Verify GID is properly configured
```bash
ibv_devinfo -v | grep -A 5 "GID"
```

---

## CONFIGURATION FILES

### /etc/netplan/00-installer-config.yaml
Location: `/etc/netplan/00-installer-config.yaml`
Permissions: `600`

### /etc/modules
For persistent kernel module loading:
```bash
cat /etc/modules
```

---

## USEFUL LINKS

- RDMA Core: https://github.com/linux-rdma/rdma-core
- Mellanox OFED: https://www.nvidia.com/networking/ethernet/mlnx-ofed/
- Linux RDMA Documentation: https://linux-rdma.org/

---

**Last Updated:** December 5, 2025
**Ubuntu Version:** 24.04 LTS
**RDMA Type:** SR-IOV with Mellanox NICs
