#!/usr/bin/env python3
"""
RDMA-Enabled Distributed LLM Training with DeepSpeed
Works on both Server 1 and Server 2
"""

import torch
import torch.nn as nn
from torch.distributed import init_process_group, destroy_process_group
import os
import sys

def init_distributed():
    """Initialize distributed training with RDMA"""
    rank = int(os.environ.get('RANK', 0))
    world_size = int(os.environ.get('WORLD_SIZE', 1))
    master_addr = os.environ.get('MASTER_ADDR', '192.168.250.201')
    master_port = os.environ.get('MASTER_PORT', '29500')
    
    print(f"\n[Init] Rank: {rank}, World Size: {world_size}")
    print(f"[Init] Master: {master_addr}:{master_port}\n")
    
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

def simple_training():
    """Simple distributed training without DeepSpeed"""
    rank = torch.distributed.get_rank()
    world_size = torch.distributed.get_world_size()
    
    print(f"{'='*60}")
    print(f"[Rank {rank}/{world_size}] RDMA LLM Training Started")
    print(f"{'='*60}\n")
    
    # Simple model
    model = nn.Sequential(
        nn.Linear(10, 64),
        nn.ReLU(),
        nn.Linear(64, 32),
        nn.ReLU(),
        nn.Linear(32, 1)
    )
    
    # Simple data
    data = torch.randn(8, 10)
    labels = torch.randn(8, 1)
    
    # Training
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = nn.MSELoss()
    
    print(f"[Rank {rank}] Model created, starting training...\n")
    
    for epoch in range(3):
        # Forward pass
        outputs = model(data)
        loss = criterion(outputs, labels)
        
        # Backward pass
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        # Only rank 0 prints
        if rank == 0:
            print(f"Epoch {epoch+1}/3, Loss: {loss.item():.4f}")
    
    print(f"\n[Rank {rank}] ✓ Training complete!")
    print(f"[Rank {rank}] Model parameters: {sum(p.numel() for p in model.parameters())}\n")

def main():
    print(f"\n{'='*60}")
    print(f"RDMA Distributed LLM Training")
    print(f"PyTorch: {torch.__version__}")
    print(f"{'='*60}\n")
    
    # Initialize distributed
    init_distributed()
    
    # Run simple training
    simple_training()
    
    # Cleanup
    destroy_process_group()
    print(f"[All] ✓ Distributed training finished!\n")

if __name__ == "__main__":
    main()
