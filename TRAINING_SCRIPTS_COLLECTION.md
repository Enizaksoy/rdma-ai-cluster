# RDMA Distributed Training Scripts Collection

## Quick Start Commands

### To use any script:
1. Copy script to your server
2. Activate virtual environment: `source rdma_llm/bin/activate`
3. Run Server 1 (Master) in terminal 1
4. Run Server 2 (Worker) in terminal 2

---

## Script 1: Simple Distributed Model (Fastest - 30 seconds)

Save as: `train_simple_distributed.py`

```python
#!/usr/bin/env python3
"""
Simplest Distributed Training Example
Train Time: ~30 seconds
RDMA Traffic: Minimal (good for testing)
"""

import torch
import torch.nn as nn
from torch.distributed import init_process_group, destroy_process_group
from torch.nn.parallel import DistributedDataParallel as DDP
import os
import sys

def init_distributed():
    rank = int(os.environ.get('RANK', 0))
    world_size = int(os.environ.get('WORLD_SIZE', 1))
    master_addr = os.environ.get('MASTER_ADDR', '192.168.250.201')
    master_port = os.environ.get('MASTER_PORT', '29500')
    
    print(f"\n[Rank {rank}] Initializing distributed training...")
    print(f"[Rank {rank}] Master: {master_addr}:{master_port}")
    
    try:
        init_process_group(
            backend='gloo',
            rank=rank,
            world_size=world_size,
            init_method=f'tcp://{master_addr}:{master_port}'
        )
        print(f"[Rank {rank}] ✓ Connected to distributed training!\n")
    except Exception as e:
        print(f"[Rank {rank}] ✗ Connection failed: {e}")
        sys.exit(1)

def main():
    init_distributed()
    
    rank = torch.distributed.get_rank()
    
    print(f"{'='*70}")
    print(f"[Rank {rank}] Simple Distributed Training")
    print(f"{'='*70}\n")
    
    # Simple model
    model = nn.Sequential(
        nn.Linear(10, 64),
        nn.ReLU(),
        nn.Linear(64, 32),
        nn.ReLU(),
        nn.Linear(32, 1)
    )
    
    # Wrap with DDP
    model = DDP(model)
    
    if rank == 0:
        print(f"[Rank {rank}] Model parameters: {sum(p.numel() for p in model.parameters()):,}\n")
    
    # Training
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = nn.MSELoss()
    
    data = torch.randn(8, 10)
    labels = torch.randn(8, 1)
    
    print(f"[Rank {rank}] Starting training...\n")
    
    for epoch in range(3):
        outputs = model(data)
        loss = criterion(outputs, labels)
        
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        if rank == 0:
            print(f"Epoch {epoch+1}/3, Loss: {loss.item():.4f}")
    
    if rank == 0:
        print(f"\n[Rank {rank}] ✓ Training completed!")
        print(f"{'='*70}\n")
    
    destroy_process_group()

if __name__ == "__main__":
    main()
```

**Run:**
```bash
# Terminal 1 (Server 1)
export RANK=0 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
python train_simple_distributed.py

# Terminal 2 (Server 2)
export RANK=1 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
python train_simple_distributed.py
```

---

## Script 2: GPT-2 Distributed Training (Recommended)

Save as: `train_gpt2_distributed.py`

```python
#!/usr/bin/env python3
"""
GPT-2 Distributed Training
Train Time: ~5 minutes
Model Size: 124.4M parameters
Good for: Understanding LLM training
"""

import torch
import torch.nn as nn
from torch.distributed import init_process_group, destroy_process_group
from torch.nn.parallel import DistributedDataParallel as DDP
from transformers import AutoTokenizer, AutoModelForCausalLM
import os
import sys
import time

def init_distributed():
    rank = int(os.environ.get('RANK', 0))
    world_size = int(os.environ.get('WORLD_SIZE', 1))
    master_addr = os.environ.get('MASTER_ADDR', '192.168.250.201')
    master_port = os.environ.get('MASTER_PORT', '29500')
    
    print(f"\n[Rank {rank}] Initializing distributed training...")
    print(f"[Rank {rank}] Master: {master_addr}:{master_port}")
    
    try:
        init_process_group(
            backend='gloo',
            rank=rank,
            world_size=world_size,
            init_method=f'tcp://{master_addr}:{master_port}'
        )
        print(f"[Rank {rank}] ✓ Connected to distributed training!\n")
    except Exception as e:
        print(f"[Rank {rank}] ✗ Connection failed: {e}")
        sys.exit(1)

def main():
    init_distributed()
    
    rank = torch.distributed.get_rank()
    
    print(f"{'='*70}")
    print(f"[Rank {rank}] GPT-2 Distributed Training")
    print(f"{'='*70}\n")
    
    # Load model
    if rank == 0:
        print(f"[Rank {rank}] Loading GPT-2 model...")
    
    model_name = "gpt2"
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    tokenizer.pad_token = tokenizer.eos_token
    model = AutoModelForCausalLM.from_pretrained(model_name)
    
    # Wrap with DDP
    model = DDP(model)
    
    if rank == 0:
        print(f"[Rank {rank}] Model loaded: {model_name}")
        print(f"[Rank {rank}] Total parameters: {sum(p.numel() for p in model.parameters()):,}\n")
    
    # Training data
    training_texts = [
        "Artificial intelligence is transforming the world with machine learning and deep learning models.",
        "Neural networks are inspired by biological neurons and can solve complex problems.",
        "Distributed computing enables training large models across multiple machines.",
        "RDMA provides low-latency, high-bandwidth network communication for data centers.",
        "GPU acceleration has revolutionized deep learning model training.",
    ]
    
    # Tokenize
    tokenized_data = []
    for text in training_texts:
        tokens = tokenizer(
            text,
            return_tensors="pt",
            padding=True,
            truncation=True,
            max_length=50
        )
        tokenized_data.append(tokens['input_ids'].squeeze())
    
    # Optimizer
    optimizer = torch.optim.AdamW(model.parameters(), lr=5e-5)
    
    print(f"[Rank {rank}] Starting training...\n")
    
    for epoch in range(3):
        total_loss = 0
        
        for idx, input_ids in enumerate(tokenized_data):
            if input_ids.dim() == 1:
                input_ids = input_ids.unsqueeze(0)
            
            outputs = model(input_ids, labels=input_ids)
            loss = outputs.loss
            
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
            
            if rank == 0:
                print(f"Epoch {epoch+1}/3, Step {idx+1}, Loss: {loss.item():.4f}")
        
        avg_loss = total_loss / len(tokenized_data)
        if rank == 0:
            print(f"[Epoch {epoch+1}] Average Loss: {avg_loss:.4f}\n")
    
    if rank == 0:
        print(f"{'='*70}")
        print(f"[Rank {rank}] ✓ Training completed!")
        print(f"[Rank {rank}] Final parameters: {sum(p.numel() for p in model.module.parameters()):,}")
        print(f"{'='*70}\n")
    
    destroy_process_group()

if __name__ == "__main__":
    main()
```

**Run:**
```bash
# Terminal 1 (Server 1)
export RANK=0 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
python train_gpt2_distributed.py

# Terminal 2 (Server 2)
export RANK=1 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
python train_gpt2_distributed.py
```

---

## Script 3: Training with Text Dataset (For Your Data)

Save as: `train_with_dataset.py`

```python
#!/usr/bin/env python3
"""
Train on Text Dataset (Markdown, Wikipedia, etc)
Dataset Source: training_data.txt
Train Time: 2-5 minutes (depends on dataset size)
Good for: Production training
"""

import torch
import torch.nn as nn
from torch.distributed import init_process_group, destroy_process_group
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader, DistributedSampler
from transformers import (
    AutoTokenizer, 
    AutoModelForCausalLM, 
    TextDataset, 
    DataCollatorForLanguageModeling
)
import os
import sys
import time

def init_distributed():
    rank = int(os.environ.get('RANK', 0))
    world_size = int(os.environ.get('WORLD_SIZE', 1))
    master_addr = os.environ.get('MASTER_ADDR', '192.168.250.201')
    master_port = os.environ.get('MASTER_PORT', '29500')
    
    print(f"\n[Rank {rank}] Initializing distributed training...")
    print(f"[Rank {rank}] Master: {master_addr}:{master_port}")
    
    try:
        init_process_group(
            backend='gloo',
            rank=rank,
            world_size=world_size,
            init_method=f'tcp://{master_addr}:{master_port}'
        )
        print(f"[Rank {rank}] ✓ Connected to distributed training!\n")
    except Exception as e:
        print(f"[Rank {rank}] ✗ Connection failed: {e}")
        sys.exit(1)

def main():
    init_distributed()
    
    rank = torch.distributed.get_rank()
    
    print(f"{'='*70}")
    print(f"[Rank {rank}] Dataset-based LLM Training")
    print(f"{'='*70}\n")
    
    # Dataset path
    dataset_path = "training_data.txt"
    
    if not os.path.exists(dataset_path):
        if rank == 0:
            print(f"❌ Dataset not found: {dataset_path}")
            print(f"Please create training_data.txt with your data")
        sys.exit(1)
    
    file_size_mb = os.path.getsize(dataset_path) / (1024*1024)
    if rank == 0:
        print(f"[Rank {rank}] Dataset: {dataset_path}")
        print(f"[Rank {rank}] File size: {file_size_mb:.2f} MB\n")
    
    # Load model
    if rank == 0:
        print(f"[Rank {rank}] Loading GPT-2 model...")
    
    model_name = "gpt2"
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    tokenizer.pad_token = tokenizer.eos_token
    model = AutoModelForCausalLM.from_pretrained(model_name)
    
    model = DDP(model)
    
    if rank == 0:
        print(f"[Rank {rank}] Model loaded: {model_name}")
        print(f"[Rank {rank}] Total parameters: {sum(p.numel() for p in model.parameters()):,}\n")
    
    # Create dataset
    dataset = TextDataset(
        tokenizer=tokenizer,
        file_path=dataset_path,
        block_size=128
    )
    
    data_collator = DataCollatorForLanguageModeling(
        tokenizer=tokenizer,
        mlm=False
    )
    
    sampler = DistributedSampler(
        dataset,
        num_replicas=2,
        rank=rank,
        shuffle=True
    )
    
    train_loader = DataLoader(
        dataset,
        batch_size=32,
        sampler=sampler,
        collate_fn=data_collator
    )
    
    optimizer = torch.optim.AdamW(model.parameters(), lr=5e-5)
    
    num_epochs = 3
    log_interval = 10
    
    if rank == 0:
        print(f"[Rank {rank}] Starting training...")
        print(f"[Rank {rank}] Batch size: 32")
        print(f"[Rank {rank}] Epochs: {num_epochs}")
        print(f"[Rank {rank}] Total samples: {len(dataset)}\n")
    
    start_time = time.time()
    
    for epoch in range(num_epochs):
        total_loss = 0
        batch_count = 0
        
        if rank == 0:
            print(f"\n{'─'*70}")
            print(f"Epoch {epoch+1}/{num_epochs}")
            print(f"{'─'*70}")
        
        for batch_idx, batch in enumerate(train_loader):
            input_ids = batch['input_ids']
            outputs = model(input_ids, labels=input_ids)
            loss = outputs.loss
            
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
            batch_count += 1
            
            if rank == 0 and batch_idx % log_interval == 0:
                print(f"  Batch {batch_idx:4d}, Loss: {loss.item():.4f}")
        
        avg_loss = total_loss / batch_count if batch_count > 0 else 0
        
        if rank == 0:
            print(f"\n[Epoch {epoch+1}] Average Loss: {avg_loss:.4f}")
    
    total_time = time.time() - start_time
    
    if rank == 0:
        print(f"\n{'='*70}")
        print(f"[Rank {rank}] ✓ Training completed!")
        print(f"[Rank {rank}] Total time: {total_time:.2f}s")
        print(f"[Rank {rank}] Dataset size: {file_size_mb:.2f} MB")
        print(f"[Rank {rank}] Parameters: {sum(p.numel() for p in model.module.parameters()):,}")
        print(f"{'='*70}\n")
    
    torch.distributed.barrier()
    destroy_process_group()

if __name__ == "__main__":
    main()
```

**Setup:**
```bash
# Copy your markdown file
cp versa-cli-commands.md training_data.txt

# Or create from multiple files
cat *.md > training_data.txt

# Run training
export RANK=0 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
python train_with_dataset.py
```

---

## How to Use These Scripts

### Step-by-Step

1. **Copy script to your server:**
   ```bash
   nano train_gpt2_distributed.py
   # (Paste script above)
   # Ctrl+X → Y → Enter
   ```

2. **Activate virtual environment:**
   ```bash
   source rdma_llm/bin/activate
   ```

3. **Terminal 1 - Server 1 (Master):**
   ```bash
   export RANK=0 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
   python train_gpt2_distributed.py
   ```

4. **Terminal 2 - Server 2 (Worker):**
   ```bash
   ssh versa@192.168.250.202
   source rdma_llm/bin/activate
   export RANK=1 WORLD_SIZE=2 MASTER_ADDR=192.168.250.201 MASTER_PORT=29500
   python train_gpt2_distributed.py
   ```

5. **Monitor RDMA (Optional - Terminal 3):**
   ```bash
   ib_send_bw -d rocep11s0 -i 1 192.168.250.202
   ```

---

## Comparison

| Script | Time | RDMA Traffic | Best For |
|--------|------|--------------|----------|
| Simple | 30s | Low | Quick testing |
| GPT-2 | 5min | Medium | Learning LLM |
| Dataset | 2-5min | High | Production |

---

## Common Issues & Quick Fixes

```bash
# If tokenizer error:
# Add this line after loading tokenizer:
# tokenizer.pad_token = tokenizer.eos_token

# If connection refused:
pkill -f python
sleep 2
# Retry training

# If module not found:
source rdma_llm/bin/activate
pip install transformers

# Check if running:
ps aux | grep python
```

---

**All scripts ready to use! Copy them to your servers and start training!** 🚀
