# AI Training Traffic Observation Guide
**Objective:** Run distributed AI training to observe RDMA traffic, ECN marking, PFC activity, and CNP packets

---

## Overview

This guide will help you:
1. Run distributed AI training across 8 servers (CPU-based)
2. Generate realistic All-Reduce traffic patterns over RDMA
3. Monitor switch queue statistics in real-time
4. Observe ECN marking (tos 0x2 → 0x3)
5. Watch PFC pause frames on fabric links
6. Track CNP packet generation and handling

---

## Step 1: Install Software Stack

**Run on your local machine:**

```bash
cd /mnt/c/Users/eniza/Documents/claudechats
bash install_ai_training_stack.sh
```

**This installs on all 8 servers:**
- Python 3 + PyTorch (CPU version)
- Horovod (distributed training library)
- OpenMPI with UCX (RDMA support)

**Time:** ~10-15 minutes

---

## Step 2: Copy Training Script to All Servers

```bash
# Copy the training script to all 8 servers
for ip in 192.168.11.152 192.168.11.153 192.168.11.154 192.168.11.155 \
          192.168.11.107 192.168.12.51 192.168.20.150 192.168.30.94; do
    sshpass -p 'Versa@123!!' scp -o StrictHostKeyChecking=no \
        train_distributed.py versa@${ip}:~/
done
```

---

## Step 3: Set Up Passwordless SSH (for MPI)

**On ubunturdma1 (master node):**

```bash
ssh versa@192.168.11.152

# Generate SSH key (press Enter for all prompts)
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

# Copy to all servers (including itself)
for ip in 192.168.11.152 192.168.11.153 192.168.11.154 192.168.11.155 \
          192.168.11.107 192.168.12.51 192.168.20.150 192.168.30.94; do
    sshpass -p 'Versa@123!!' ssh-copy-id -o StrictHostKeyChecking=no versa@${ip}
done
```

---

## Step 4: Configure Environment for RDMA

**On ubunturdma1, create a hostfile:**

```bash
cat > ~/hostfile << 'EOF'
192.168.11.152 slots=1
192.168.11.153 slots=1
192.168.11.154 slots=1
192.168.11.155 slots=1
192.168.11.107 slots=1
192.168.12.51 slots=1
192.168.20.150 slots=1
192.168.30.94 slots=1
EOF
```

**Create launch script:**

```bash
cat > ~/run_training.sh << 'EOF'
#!/bin/bash

echo "=== Starting Distributed AI Training on 8 Servers ==="
echo "This will generate All-Reduce traffic over RDMA"
echo ""

# UCX/RDMA configuration
export UCX_NET_DEVICES=mlx5_0:1,mlx5_2:1  # Use Mellanox RDMA devices
export UCX_TLS=rc,sm                       # rc = RDMA Connection, sm = Shared Memory
export UCX_RNDV_SCHEME=put_zcopy          # Zero-copy RDMA
export HOROVOD_MPI_THREADS_DISABLE=1
export OMP_NUM_THREADS=4

echo "RDMA Configuration:"
echo "  UCX_NET_DEVICES: $UCX_NET_DEVICES"
echo "  UCX_TLS: $UCX_TLS"
echo ""
echo "Starting training in 5 seconds..."
echo "OPEN YOUR MONITORING WINDOWS NOW!"
sleep 5

# Run distributed training with Horovod
horovodrun -np 8 \
    --hostfile ~/hostfile \
    --mpi-args="--mca btl_tcp_if_include ens224,ens192 --mca oob_tcp_if_include ens160" \
    python3 ~/train_distributed.py

echo ""
echo "=== Training Complete ==="
echo "Check your monitoring windows for ECN/PFC/CNP activity!"
EOF

chmod +x ~/run_training.sh
```

---

## Step 5: Set Up Monitoring (IMPORTANT!)

**Open 4 SEPARATE terminal windows on your local machine:**

### Terminal 1: Switch Queue Monitor (Drops & ECN)

```bash
watch -n 1 'sshpass -p "Versa@123!!" ssh admin@192.168.50.229 "show queuing interface ethernet1/1/1" | grep -E "Ingress MMU Drop|WRED Drop|Tx Pkts|QOS GROUP 3"'
```

**What to watch:**
- `Ingress MMU Drop Pkts`: Should increase slowly (or stay same if perfect)
- `WRED Drop Pkts`: Should stay 0 (ECN marks instead of drops)
- `Tx Pkts (QOS GROUP 3)`: Should increase rapidly during training

---

### Terminal 2: Switch PFC Activity

```bash
watch -n 1 'sshpass -p "Versa@123!!" ssh admin@192.168.50.229 "show interface priority-flow-control | grep -E \"Ethernet1/1|ii1/1\" | head -20"'
```

**What to watch:**
- `Ethernet1/1/1-4` (edge ports): RxPPP/TxPPP may increase if bursts occur
- `ii1/1/1-6` (fabric): RxPPP should increase (millions of pause frames)

---

### Terminal 3: Server RDMA/CNP Statistics

```bash
watch -n 1 'sshpass -p "Versa@123!!" ssh versa@192.168.11.107 "rdma statistic show link rocep11s0/1 2>/dev/null | grep -E \"cnp|ecn\""'
```

**What to watch:**
- `rp_cnp_handled`: Increases = receiving CNPs, slowing down
- `np_ecn_marked_roce_packets`: Increases = receiving CE-marked packets from switch
- `np_cnp_sent`: Increases = sending CNPs back to senders

---

### Terminal 4: Training Output

```bash
ssh versa@192.168.11.152
tail -f ~/training.log  # (after you start training)
```

---

## Step 6: RUN THE TRAINING!

**On ubunturdma1:**

```bash
ssh versa@192.168.11.152
./run_training.sh 2>&1 | tee ~/training.log
```

**What happens:**
1. All 8 servers start training in parallel
2. Every iteration (~500ms), they perform All-Reduce:
   - Each server sends ~150MB gradients
   - All servers exchange data simultaneously
   - Total network traffic: ~1.2GB per iteration
3. This triggers:
   - RDMA traffic on your RoCEv2 network
   - ECN marking when queues fill (tos 0x2 → 0x3)
   - CNP packets sent back to senders
   - PFC pause frames on fabric (if severe congestion)

---

## Step 7: Observe the Network Behavior

### What You Should See:

**Switch (Terminal 1 & 2):**
```
✅ QOS GROUP 3 Tx Pkts: Rapidly increasing (millions)
✅ WRED Drop Pkts: 0 (ECN working!)
⚠️ Ingress MMU Drop Pkts: May increase slightly (your 0.29%)
✅ ii1/1/x RxPPP: Increasing (fabric PFC active)
```

**Servers (Terminal 3):**
```
✅ np_ecn_marked_roce_packets: Rapidly increasing
✅ np_cnp_sent: Increasing (sending CNPs)
✅ rp_cnp_handled: Increasing (receiving & handling CNPs)
```

**Training (Terminal 4):**
```
Iteration   10 | Loss: 2.3045 | AllReduce: 45.2ms | Total: 156.3ms
  → Network traffic: All 8 servers exchanging ~150.5MB gradients
  → Check switch stats NOW for ECN/PFC activity!

Iteration   20 | Loss: 2.2891 | AllReduce: 48.7ms | Total: 158.1ms
  ...
```

---

## Step 8: Packet Capture (Optional)

**While training is running, capture packets on one server:**

```bash
# On a separate terminal
ssh versa@192.168.20.150

sudo timeout 10 docker run --rm \
    -v /dev/infiniband:/dev/infiniband \
    --net=host --privileged \
    mellanox/tcpdump-rdma \
    tcpdump -i rocep11s0 -c 100 -nn -v 'udp' 2>&1 | grep "tos 0x"
```

**Expected output:**
```
tos 0x2  ← ECT (ECN-Capable Transport) - sent by sender
tos 0x2
tos 0x3  ← CE (Congestion Experienced) - MARKED BY SWITCH!
tos 0x2
tos 0x3  ← Another CE-marked packet!
...
```

---

## Understanding What You're Seeing

### The Complete Flow:

```
1. Training Script (All 8 Servers):
   ├─ Compute gradients locally
   ├─ Call optimizer.step()
   └─ Horovod triggers All-Reduce

2. Horovod All-Reduce:
   ├─ Uses MPI over UCX
   ├─ UCX uses RDMA (RoCEv2)
   └─ All 8 servers send ~150MB simultaneously

3. RDMA Network (Your Setup):
   ├─ NICs set ECT bits (tos 0x2)
   ├─ Packets traverse fabric
   └─ RDMA kernel bypass (no TCP!)

4. Switch Congestion Point:
   ├─ Queue fills on egress
   ├─ WRED detects congestion
   ├─ Switch marks ECT → CE (tos 0x3)
   └─ Forwards CE-marked packets

5. Receiver NIC:
   ├─ Sees CE-marked packets
   ├─ Increments np_ecn_marked_roce_packets
   ├─ Sends CNP back to sender
   └─ Increments np_cnp_sent

6. Sender NIC:
   ├─ Receives CNP packet
   ├─ Increments rp_cnp_handled
   ├─ Reduces transmission rate (DCQCN)
   └─ Prevents further congestion

7. PFC Safety Net:
   ├─ If ECN not enough, queues still fill
   ├─ Switch sends PFC pause frame
   ├─ Upstream stops sending temporarily
   └─ Prevents packet drops
```

---

## Expected Observations

### Successful ECN/PFC Operation:

✅ **No or minimal ingress drops** (ECN preventing drops)
✅ **0 WRED drops** (ECN marking instead)
✅ **Millions of ECN-marked packets** (np_ecn_marked_roce_packets)
✅ **Millions of CNP packets** (np_cnp_sent, rp_cnp_handled)
✅ **PFC active on fabric** (ii1/1/x showing millions of pause frames)
✅ **Consistent AllReduce times** (45-60ms per iteration)

### If You See Problems:

⚠️ **Ingress drops increasing rapidly** → Buffer too small for burst size
⚠️ **AllReduce time increasing** → Network congestion slowing training
⚠️ **Timeouts or errors** → 0.29% drops causing RDMA retransmissions
⚠️ **PFC on edge ports** → Severe congestion, ECN not enough

---

## Stopping the Training

**Press Ctrl+C** in the training terminal (Terminal 4)

Training will gracefully stop on all servers.

---

## Post-Training Analysis

**Compare before/after statistics:**

```bash
# Switch - check total drops
sshpass -p "Versa@123!!" ssh admin@192.168.50.229 \
    "show queuing interface ethernet1/1/1" | grep "Ingress MMU Drop"

# Server - check CNP activity
sshpass -p "Versa@123!!" ssh versa@192.168.11.107 \
    "rdma statistic show link rocep11s0/1" | grep -E "cnp|ecn"
```

---

## Summary

You now have a complete setup to:
- ✅ Generate realistic AI training traffic (All-Reduce over RDMA)
- ✅ Observe ECN marking in action (tos 0x2 → 0x3)
- ✅ Monitor PFC pause frames on fabric
- ✅ Track CNP packet generation and handling
- ✅ Validate your entire ECN/PFC/RDMA configuration

**This is exactly what happens in a real GPU cluster, just slower!**

---

## Files Created

- `install_ai_training_stack.sh` - Install software on all servers
- `train_distributed.py` - Distributed training script
- `monitor_training_traffic.sh` - Monitoring commands reference
- `AI_TRAINING_OBSERVATION_GUIDE.md` - This document

**Ready to proceed?**
