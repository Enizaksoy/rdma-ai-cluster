# AI/ML Cluster Setup and Usage Guide

**Created:** 2025-12-29
**Cluster:** 8-Node RDMA AI Cluster
**Status:** Ready for AI/ML workloads

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Available Scripts](#available-scripts)
3. [Installation Steps](#installation-steps)
4. [Testing and Verification](#testing-and-verification)
5. [Distributed Training](#distributed-training)
6. [Performance Benchmarks](#performance-benchmarks)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### 1. Install AI/ML Stack (First Time Setup)

**From Windows:**
```batch
C:\Users\eniza\Documents\claudechats\INSTALL_AIML_STACK.bat
```

**From WSL:**
```bash
cd /mnt/c/Users/eniza/Documents/claudechats
./install_aiml_stack.sh
```

**Duration:** 10-15 minutes

---

## Available Scripts

### Installation & Setup

| File | Purpose | Runtime |
|------|---------|---------|
| `INSTALL_AIML_STACK.bat` | Install PyTorch and ML tools | 10-15 min |
| `install_aiml_stack.sh` | Bash version (WSL/Linux) | 10-15 min |

### Verification

| File | Purpose | Runtime |
|------|---------|---------|
| `VERIFY_AIML.bat` | Verify installation on all servers | 1 min |
| `verify_aiml_installation.sh` | Bash version | 1 min |

### Testing

| File | Purpose | Runtime |
|------|---------|---------|
| `TEST_DISTRIBUTED.bat` | Test distributed training | 2-3 min |
| `test_distributed_training.sh` | Bash version | 2-3 min |
| `TEST_RDMA_BANDWIDTH.bat` | Test RDMA performance | 1-2 min |
| `test_rdma_bandwidth.sh` | Bash version | 1-2 min |
| `RUN_RDMA_TESTS.bat` | Full RDMA verification suite | 2-3 min |
| `rdma_full_test.sh` | Bash version | 2-3 min |

### Documentation

| File | Purpose |
|------|---------|
| `AIML_CLUSTER_GUIDE.md` | This guide |
| `RDMA_TEST_GUIDE.md` | RDMA testing guide |
| `AI_CLUSTER_INVENTORY.md` | Cluster inventory |
| `RDMA_VERIFICATION_REPORT.md` | RDMA verification results |

---

## Installation Steps

### Step 1: Install AI/ML Stack

Run the installation script to set up all 8 servers:

```batch
INSTALL_AIML_STACK.bat
```

**What gets installed:**

✅ **Python Environment**
- Python 3 with pip
- Development tools (build-essential)
- Virtual environment support

✅ **Machine Learning Frameworks**
- PyTorch (CPU version)
- TorchVision
- TorchAudio

✅ **Distributed Computing**
- MPI4py (Message Passing Interface)
- OpenMPI libraries

✅ **Data Science Tools**
- NumPy - Numerical computing
- Pandas - Data manipulation
- Scikit-learn - Machine learning
- Matplotlib - Visualization
- Jupyter - Interactive notebooks
- TensorBoard - Training visualization

✅ **Workspace Setup**
- Creates `/home/versa/ai_workspace` on all servers
- Ready for code deployment

### Step 2: Verify Installation

Check that everything installed correctly:

```batch
VERIFY_AIML.bat
```

**Expected output for each server:**
```
Python: 3.x.x
PyTorch: 2.x.x
CUDA Available: False (CPU version)
CPU Threads: X
NumPy: 1.x.x
Pandas: 2.x.x
MPI4Py: Installed
```

---

## Testing and Verification

### RDMA Performance Test

Verify RDMA bandwidth between servers:

```batch
TEST_RDMA_BANDWIDTH.bat
```

**Expected Results:**
- **Vlan251:** 5-7 GB/sec (10 GbE)
- **Vlan250:** 5-7 GB/sec (10 GbE)

**Test Configuration:**
- Uses `ib_write_bw` tool
- 64KB message size
- 10-second duration
- Tests both VLANs

### Full RDMA Test Suite

Comprehensive 9-test suite:

```batch
RUN_RDMA_TESTS.bat
```

**Tests include:**
1. Network interface discovery
2. RDMA hardware detection
3. Kernel module verification
4. Vlan251 connectivity
5. Vlan250 connectivity
6. Cross-VLAN routing
7. RDMA bandwidth (Vlan251)
8. RDMA bandwidth (Vlan250)
9. Detailed device information

---

## Distributed Training

### Test Distributed Training

Run a simple 4-node distributed training test:

```batch
TEST_DISTRIBUTED.bat
```

**Configuration:**
- **Cluster:** 4 nodes on Vlan251
- **Master:** ubunturdma1 (192.168.251.111)
- **Workers:** ubunturdma3, ubunturdma6, ubunturdma8
- **Backend:** Gloo (CPU)
- **Model:** Simple neural network
- **Epochs:** 5

### Manual Distributed Training

#### On Master Node (ubunturdma1)

```bash
ssh versa@192.168.11.152

cd /home/versa/ai_workspace

export MASTER_ADDR=192.168.251.111
export MASTER_PORT=29500
export WORLD_SIZE=4
export RANK=0

python3 your_training_script.py
```

#### On Worker Nodes

```bash
# ubunturdma3 (rank 1)
export MASTER_ADDR=192.168.251.111
export MASTER_PORT=29500
export WORLD_SIZE=4
export RANK=1
python3 your_training_script.py

# ubunturdma6 (rank 2)
export RANK=2
python3 your_training_script.py

# ubunturdma8 (rank 3)
export RANK=3
python3 your_training_script.py
```

### PyTorch Distributed Code Template

```python
import torch
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP

# Initialize process group
dist.init_process_group(
    backend='gloo',  # Use 'nccl' for GPU
    init_method='env://'
)

# Get rank and world size
rank = dist.get_rank()
world_size = dist.get_world_size()

# Create model and wrap with DDP
model = YourModel()
ddp_model = DDP(model)

# Training loop
for epoch in range(num_epochs):
    for batch in dataloader:
        outputs = ddp_model(batch)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

# Cleanup
dist.destroy_process_group()
```

---

## Performance Benchmarks

### Expected Performance

#### Network Performance
| Metric | Vlan251 | Vlan250 |
|--------|---------|---------|
| Ping Latency | < 1 ms | < 1 ms |
| Packet Loss | 0% | 0% |
| RDMA Bandwidth | 6+ GB/sec | 6+ GB/sec |

#### Compute Performance (Per Node)
| Metric | Value |
|--------|-------|
| CPU Cores | Varies by server |
| Memory | Check per server |
| Storage | Check per server |

### Cluster Configurations

#### 4-Node Cluster (Vlan251) - Recommended
- **Nodes:** ubunturdma1, 3, 6, 8
- **Network:** Single RDMA subnet
- **Advantages:**
  - Optimal NCCL performance
  - Simplified configuration
  - Better consistency

#### 8-Node Cluster (All Servers)
- **Nodes:** All 8 servers
- **Network:** Mixed (Vlan251 + Vlan250)
- **Advantages:**
  - 2x compute capacity
  - Fault tolerance
- **Considerations:**
  - Requires cross-VLAN routing
  - May need NCCL tuning

---

## Troubleshooting

### Installation Issues

**Problem:** Script fails to connect to servers
```bash
# Solution: Check network connectivity
ping 192.168.11.152

# Verify credentials
ssh versa@192.168.11.152
```

**Problem:** Package installation fails
```bash
# Solution: Update package lists
sudo apt-get update
sudo apt-get upgrade
```

**Problem:** Pip install errors
```bash
# Solution: Upgrade pip
pip3 install --upgrade pip

# Install with verbose output
pip3 install --user torch --verbose
```

### Distributed Training Issues

**Problem:** Nodes can't connect to master
```bash
# Check RDMA network connectivity
ping 192.168.251.111

# Verify firewall
sudo ufw status

# Check port is accessible
nc -zv 192.168.251.111 29500
```

**Problem:** Training hangs at initialization
```bash
# Increase timeout
export NCCL_SOCKET_TIMEOUT=300

# Enable debug logging
export TORCH_DISTRIBUTED_DEBUG=DETAIL
```

**Problem:** Poor performance
```bash
# Check CPU usage
top

# Check network usage
iftop -i ens224

# Verify RDMA is being used
ibstat
```

### RDMA Issues

**Problem:** No RDMA devices found
```bash
# Check modules loaded
lsmod | grep rdma

# Reload modules
sudo modprobe rdma_cm
sudo modprobe ib_uverbs

# Verify hardware
ibv_devices
```

**Problem:** Low RDMA bandwidth
```bash
# Check MTU settings
ip addr show ens192

# Verify link state
ibv_devinfo | grep state

# Test with different parameters
ib_write_bw -d rocep11s0 -s 65536
```

---

## Advanced Configuration

### Installing GPU Support (If Available)

```bash
# Install CUDA toolkit (if NVIDIA GPUs present)
sudo apt-get install nvidia-cuda-toolkit

# Install PyTorch with CUDA
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

### Configuring NCCL for Better Performance

```bash
# Set NCCL environment variables
export NCCL_DEBUG=INFO
export NCCL_SOCKET_IFNAME=ens224,ens192
export NCCL_IB_DISABLE=0
export NCCL_NET_GDR_LEVEL=5
```

### Setting Up Shared Storage (NFS)

```bash
# On master node
sudo apt-get install nfs-kernel-server
sudo mkdir -p /mnt/shared
sudo chmod 777 /mnt/shared

# Export directory
echo "/mnt/shared *(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
sudo exportfs -ra

# On worker nodes
sudo apt-get install nfs-common
sudo mkdir -p /mnt/shared
sudo mount master_ip:/mnt/shared /mnt/shared
```

---

## Cluster Information

### Server Inventory

| Server | Management IP | RDMA IP | VLAN | RDMA Device |
|--------|---------------|---------|------|-------------|
| ubunturdma1 | 192.168.11.152 | 192.168.251.111 | 251 | rocep19s0 |
| ubunturdma2 | 192.168.11.153 | 192.168.250.112 | 250 | rocep11s0 |
| ubunturdma3 | 192.168.11.154 | 192.168.251.113 | 251 | rocep19s0 |
| ubunturdma4 | 192.168.11.155 | 192.168.250.114 | 250 | rocep11s0 |
| ubunturdma5 | 192.168.11.107 | 192.168.250.115 | 250 | rocep11s0, rocep19s0f1 |
| ubunturdma6 | 192.168.12.51 | 192.168.251.116 | 251 | rocep11s0, rocep19s0f1 |
| ubunturdma7 | 192.168.20.150 | 192.168.250.117 | 250 | rocep11s0 |
| ubunturdma8 | 192.168.30.94 | 192.168.251.118 | 251 | rocep11s0 |

### Credentials
- **Username:** versa
- **Password:** Versa@123!!

---

## Next Steps

1. ✅ **Cluster Verified** - RDMA and network working
2. ✅ **Scripts Created** - Ready for installation
3. → **Install AI/ML Stack** - Run installation script
4. → **Test Distributed Training** - Verify cluster works
5. → **Deploy Your Models** - Start training!

---

## Support and Resources

### PyTorch Documentation
- Official Docs: https://pytorch.org/docs/
- Distributed Training: https://pytorch.org/tutorials/beginner/dist_overview.html
- NCCL Backend: https://pytorch.org/docs/stable/distributed.html#nccl-backend

### RDMA/RoCE Resources
- InfiniBand Verbs: https://linux.die.net/man/3/ibv_create_qp
- RoCE Configuration: https://enterprise-support.nvidia.com/s/article/howto-configure-roce

### Example Training Scripts
- PyTorch Examples: https://github.com/pytorch/examples
- Distributed Examples: https://github.com/pytorch/examples/tree/main/distributed

---

**Document Version:** 1.0
**Last Updated:** 2025-12-29
**Status:** Production Ready
