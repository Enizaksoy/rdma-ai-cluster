# RDMA Test Script Guide

## Quick Start

### Option 1: Run from Windows (Easiest)
```batch
C:\Users\eniza\Documents\claudechats\RUN_RDMA_TESTS.bat
```

### Option 2: Run from WSL
```bash
cd /mnt/c/Users/eniza/Documents/claudechats
./rdma_full_test.sh
```

## What the Script Tests

The script performs **9 comprehensive tests** across all 8 servers:

### 1. Network Interface Discovery
- Lists all network interfaces on each server
- Identifies management and RDMA IPs
- Verifies interface names (ens160, ens192, ens224)

### 2. RDMA Hardware Detection
- Checks for RDMA devices on all servers
- Lists RoCE device names (rocep11s0, rocep19s0, etc.)
- Verifies hardware is recognized by the OS

### 3. RDMA Kernel Modules
- Lists loaded RDMA kernel modules
- Checks for ib_core, rdma_cm, rdma_ucm
- Verifies driver installation

### 4. Network Connectivity - Vlan251
- Pings between all Vlan251 servers
- Tests: ubunturdma1, 3, 6, 8
- Verifies 0% packet loss

### 5. Network Connectivity - Vlan250
- Pings between all Vlan250 servers
- Tests: ubunturdma2, 4, 5, 7
- Verifies 0% packet loss

### 6. Cross-VLAN Connectivity
- Tests connectivity between Vlan251 and Vlan250
- Verifies routing is working
- Important for 8-node cluster setup

### 7. RDMA Bandwidth Test - Vlan251
- Runs ib_write_bw between ubunturdma1 and ubunturdma3
- Measures actual RDMA throughput
- Expected: ~6 GB/sec

### 8. RDMA Bandwidth Test - Vlan250
- Runs ib_write_bw between ubunturdma4 and ubunturdma2
- Measures actual RDMA throughput
- Expected: ~6 GB/sec

### 9. Detailed RDMA Device Information
- Runs ibv_devinfo on all servers
- Shows detailed hardware capabilities
- Includes port state, MTU, link layer info

## Output

The script creates a timestamped results file:
```
C:\Users\eniza\Documents\claudechats\rdma_test_results_YYYYMMDD_HHMMSS.txt
```

Results are also displayed in real-time with color coding:
- 🟢 **GREEN** = Success
- 🔴 **RED** = Failed
- 🔵 **BLUE** = Section headers
- 🟡 **YELLOW** = Subsection headers

## Expected Results

### All Tests Should Show:
✅ All 8 servers have RDMA devices
✅ RDMA modules loaded on all servers
✅ 0% packet loss within VLANs
✅ RDMA bandwidth ~6 GB/sec on both VLANs
✅ All devices show "PORT_ACTIVE" state

## Troubleshooting

### If Script Fails to Connect:
1. Verify password is correct: `Versa@123!!`
2. Check network connectivity: `ping 192.168.11.152`
3. Ensure expect is installed: `which expect`

### If RDMA Tests Fail:
1. Check RDMA modules: `lsmod | grep rdma`
2. Verify devices exist: `ibv_devices`
3. Check interface status: `ip link show`

### If Bandwidth is Low:
1. Verify MTU settings: `ip addr show ens192`
2. Check for packet loss in ping tests
3. Ensure no CPU throttling or high load

## Script Features

- **Automated:** No manual intervention required
- **Comprehensive:** Tests all 9 critical aspects
- **Logged:** All output saved to timestamped file
- **Color-coded:** Easy to spot issues
- **Safe:** Read-only tests, no configuration changes

## Runtime

Expected completion time: **2-3 minutes**

- Network discovery: ~20 seconds
- Hardware detection: ~20 seconds
- Ping tests: ~30 seconds
- RDMA bandwidth tests: ~60 seconds
- Device info: ~30 seconds

## Credentials Used

- **Username:** versa
- **Password:** Versa@123!!
- **Method:** SSH with expect (no SSH keys)

## Servers Tested

| Server | Management IP | RDMA IP | VLAN |
|--------|---------------|---------|------|
| ubunturdma1 | 192.168.11.152 | 192.168.251.111 | 251 |
| ubunturdma2 | 192.168.11.153 | 192.168.250.112 | 250 |
| ubunturdma3 | 192.168.11.154 | 192.168.251.113 | 251 |
| ubunturdma4 | 192.168.11.155 | 192.168.250.114 | 250 |
| ubunturdma5 | 192.168.11.107 | 192.168.250.115 | 250 |
| ubunturdma6 | 192.168.12.51 | 192.168.251.116 | 251 |
| ubunturdma7 | 192.168.20.150 | 192.168.250.117 | 250 |
| ubunturdma8 | 192.168.30.94 | 192.168.251.118 | 251 |

## After Running Tests

Once all tests pass:
1. Review the results file
2. Confirm all bandwidth tests show ~6 GB/sec
3. Verify 0% packet loss on all ping tests
4. Proceed to install AI/ML stack (PyTorch, NCCL)

---

**Created:** 2025-12-28
**Version:** 1.0
**Author:** Claude (AI Assistant)
