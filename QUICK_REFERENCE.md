# RDMA LLM Cluster - Quick Reference Guide

**Print this or save to phone!** 📋

---

## 🚀 Quick Start (Copy-Paste Ready)

### Server 1 Setup
```bash
hostname
# Should show: ubunturdma1

source rdma_llm/bin/activate
export RANK=0 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
python train_gpt2_distributed.py
```

### Server 2 Setup
```bash
ssh versa@192.168.250.202
hostname
# Should show: ubunturdma2

source rdma_llm/bin/activate
export RANK=1 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
python train_gpt2_distributed.py
```

---

## ✅ Checklist Before Training

- [ ] Network connectivity
  ```bash
  ping 192.168.250.201  # From Server 2
  ping 192.168.250.202  # From Server 1
  ```

- [ ] RDMA devices UP
  ```bash
  ibv_devinfo | grep "state: PORT_ACTIVE"
  ```

- [ ] OpenSM running
  ```bash
  sudo systemctl status opensm
  sminfo
  ```

- [ ] Python environment
  ```bash
  source rdma_llm/bin/activate
  python -c "import torch; print(torch.__version__)"
  ```

- [ ] Scripts copied
  ```bash
  ls -la train_*.py
  ```

---

## 📊 Monitoring Commands

### RDMA Performance (Real-Time)
```bash
ib_send_bw -d rocep11s0 -i 1 192.168.250.202
# Expected: 1000+ MB/sec
```

### Network Traffic
```bash
watch -n 1 'ifstat -i ens192'
# or
nload -u M
```

### Process CPU/Memory
```bash
top -p $(pgrep python)
```

---

## 🔧 Troubleshooting Quick Fixes

### Port DOWN on RDMA
```bash
sudo systemctl restart opensm
sleep 30
ibv_devinfo  # Check if PORT_ACTIVE now
```

### Connection Refused
```bash
pkill -f python
sleep 2
# Retry training
```

### Tokenizer Error
**Add this line in script after loading tokenizer:**
```python
tokenizer.pad_token = tokenizer.eos_token
```

### Python Module Not Found
```bash
source rdma_llm/bin/activate
pip install transformers
```

### Different Hostnames Issue
**Server 2:**
```bash
sudo hostnamectl set-hostname ubunturdma2
sudo nano /etc/hosts  # Change 127.0.0.1 ubunturdma2
sudo reboot
```

---

## 📝 Key IPs & Ports

```
Server 1:
  Hostname: ubunturdma1
  RDMA IP: 192.168.250.201
  Management: 192.168.48.175
  RDMA Device: rocep11s0
  Rank: 0 (Master)

Server 2:
  Hostname: ubunturdma2
  RDMA IP: 192.168.250.202
  Management: 192.168.48.x
  RDMA Device: rocep11s0
  Rank: 1 (Worker)

Distributed Training:
  Master Port: 29500
  Backend: GLOO
  Network: ens192
```

---

## 📋 File Locations

```
Configuration:
  /etc/netplan/00-installer-config.yaml

Python Scripts:
  ~/train_simple_distributed.py
  ~/train_gpt2_distributed.py
  ~/train_with_dataset.py

Python Environment:
  ~/rdma_llm/
  ~/rdma_llm/bin/activate

Dataset:
  ~/training_data.txt
```

---

## 🎯 Expected Performance

### RDMA Metrics
- Latency: 6.13 µs
- Jitter: 0.15 µs
- Bandwidth: 1098 MB/sec
- QoS Priority: Level 1

### Training Metrics
- Simple model: ~30 seconds
- GPT-2: ~5 minutes per epoch
- Loss improvement: 75%+ per 3 epochs
- Network traffic: 1 GB per iteration

---

## 🔄 Typical Training Flow

1. **Terminal 1 - Server 1:**
   ```bash
   source rdma_llm/bin/activate
   export RANK=0 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
   python train_gpt2_distributed.py
   ```

2. **Terminal 2 - Server 2:**
   ```bash
   ssh versa@192.168.250.202
   source rdma_llm/bin/activate
   export RANK=1 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
   python train_gpt2_distributed.py
   ```

3. **Terminal 3 - Monitor (Optional):**
   ```bash
   ib_send_bw -d rocep11s0 -i 1 192.168.250.202
   ```

4. **Wait for training to complete**
   - Watch loss decrease
   - Monitor RDMA bandwidth
   - Check system resources

---

## 📚 Documentation Files

Saved to `/mnt/user-data/outputs/`:

1. **RDMA_LLM_CLUSTER_COMPLETE_DOCUMENTATION.md**
   - Full setup guide
   - Network architecture
   - QoS configuration
   - Troubleshooting

2. **TRAINING_SCRIPTS_COLLECTION.md**
   - All training scripts
   - Usage examples
   - Script comparison

3. **QUICK_REFERENCE.md** (This file)
   - Quick commands
   - Checklists
   - Common fixes

---

## 🚨 If Everything Fails

```bash
# Check everything
ping 192.168.250.202
ibv_devinfo | head -20
sminfo
ps aux | grep opensm

# Restart everything
sudo systemctl restart opensm
pkill -f python
sleep 5

# Try again
# (see Quick Start section above)
```

---

## 📊 QoS Configuration Verification

**Check that QoS is working:**
```bash
# On Cisco Switch:
show policy-map interface ethernet 1/1/2
show queuing interface ethernet 1/1/2

# Expected:
# Service-policy (qos) input: QOS_MARKING
# Service-policy (queuing) output: default-out-policy
# Class c-out-q3: priority level 1 ← RDMA
```

---

## 💡 Pro Tips

1. **Use tmux/screen for multiple terminals:**
   ```bash
   tmux new-session -d -s training
   tmux send-keys -t training "ssh versa@192.168.250.202" Enter
   ```

2. **Monitor with watch command:**
   ```bash
   watch -n 5 'ibv_devinfo | grep -E "state|sm_lid"'
   ```

3. **Log training output:**
   ```bash
   python train_gpt2_distributed.py | tee training.log
   ```

4. **Run in background:**
   ```bash
   nohup python train_gpt2_distributed.py > training.log 2>&1 &
   ```

---

## 🔗 Quick Links (Save These!)

- **Documentation:** `/mnt/user-data/outputs/RDMA_LLM_CLUSTER_COMPLETE_DOCUMENTATION.md`
- **Scripts:** `/mnt/user-data/outputs/TRAINING_SCRIPTS_COLLECTION.md`
- **This Guide:** `/mnt/user-data/outputs/QUICK_REFERENCE.md`

---

## ❓ Common Questions

**Q: Can I train with my own data?**
A: Yes! Copy your markdown/text file to `training_data.txt` and use `train_with_dataset.py`

**Q: How to scale to more servers?**
A: Change WORLD_SIZE=2 to WORLD_SIZE=4 (or higher), set RANK accordingly

**Q: Can I use GPU?**
A: Yes, but need NVIDIA hardware. Current setup uses CPU which is fine for learning

**Q: How much RDMA bandwidth am I using?**
A: ~1-6 Gbps during training (out of 19 Gbps available)

**Q: Why use RDMA instead of Ethernet?**
A: 10× faster synchronization (0.5s vs 5s per iteration)

---

## 🎓 What You Learned

✅ RDMA networking fundamentals
✅ Distributed PyTorch training
✅ Cisco QoS configuration
✅ LLM model training
✅ Network performance optimization
✅ Gradient synchronization

---

## 📌 Important Reminders

- **Keep QoS enabled** for stable RDMA
- **Different hostnames** on each server (critical!)
- **Virtual environment** must be activated before training
- **Master port 29500** must be accessible from both servers
- **RANK=0** on Server 1, **RANK=1** on Server 2
- **WORLD_SIZE=2** for 2 servers

---

**Last Update:** December 5, 2025
**Status:** ✅ All Systems Operational
**Ready for:** Production LLM Training

---

## 🆘 Emergency Contact

If something breaks:

1. Check `/etc/netplan/00-installer-config.yaml`
2. Verify hostnames: `hostname` on each server
3. Restart OpenSM: `sudo systemctl restart opensm`
4. Check RDMA: `ibv_devinfo`
5. Read full documentation (link above)

**Good luck! You've got this!** 🚀
