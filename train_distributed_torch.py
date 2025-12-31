#!/usr/bin/env python3
"""
Distributed AI Training using PyTorch torch.distributed
Generates All-Reduce traffic over RDMA to test ECN/PFC

Uses torch.distributed.elastic for simplified multi-node training
"""

import torch
import torch.nn as nn
import torch.optim as optim
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
import time
import os

def setup_distributed():
    """Initialize distributed training environment"""
    # Get distributed training parameters from environment
    rank = int(os.environ.get('RANK', 0))
    world_size = int(os.environ.get('WORLD_SIZE', 1))
    local_rank = int(os.environ.get('LOCAL_RANK', 0))
    master_addr = os.environ.get('MASTER_ADDR', 'localhost')
    master_port = os.environ.get('MASTER_PORT', '29500')

    # Initialize process group with Gloo backend (CPU-friendly)
    dist.init_process_group(
        backend='gloo',  # Use Gloo for CPU training
        init_method=f'tcp://{master_addr}:{master_port}',
        world_size=world_size,
        rank=rank
    )

    return rank, world_size

class LargeModel(nn.Module):
    """Large neural network to generate substantial gradient traffic"""
    def __init__(self):
        super(LargeModel, self).__init__()
        # Large layers to generate ~150MB of gradients per iteration
        self.fc1 = nn.Linear(10000, 5000)
        self.fc2 = nn.Linear(5000, 2000)
        self.fc3 = nn.Linear(2000, 1000)
        self.fc4 = nn.Linear(1000, 100)
        self.fc5 = nn.Linear(100, 10)

    def forward(self, x):
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        x = torch.relu(self.fc3(x))
        x = torch.relu(self.fc4(x))
        x = self.fc5(x)
        return x

def generate_batch(batch_size=256):
    """Generate dummy training data"""
    data = torch.randn(batch_size, 10000)
    labels = torch.randint(0, 10, (batch_size,))
    return data, labels

def main():
    # Setup distributed training
    rank, world_size = setup_distributed()

    print(f"[Rank {rank}/{world_size}] Starting distributed training")

    # Create model and wrap with DDP
    model = LargeModel()
    ddp_model = DDP(model)

    # Calculate model size
    param_count = sum(p.numel() for p in model.parameters())
    gradient_size_mb = sum(p.numel() * 4 for p in model.parameters()) / 1024 / 1024

    if rank == 0:
        print(f"Model parameters: {param_count:,}")
        print(f"Gradient size per server: ~{gradient_size_mb:.1f} MB")
        print(f"Total All-Reduce traffic: ~{gradient_size_mb * world_size:.1f} MB per iteration")
        print("")

    # Optimizer and loss function
    optimizer = optim.SGD(ddp_model.parameters(), lr=0.01)
    criterion = nn.CrossEntropyLoss()

    # Training loop
    num_iterations = 1000
    batch_size = 256

    if rank == 0:
        print("=== Starting Training Loop ===")
        print("This will generate sustained All-Reduce traffic over RDMA")
        print("Monitor your switch and server statistics NOW!")
        print("")

    for iteration in range(num_iterations):
        start_time = time.time()

        # Generate batch
        data, labels = generate_batch(batch_size)

        # Forward pass
        optimizer.zero_grad()
        outputs = ddp_model(data)
        loss = criterion(outputs, labels)

        # Backward pass (compute gradients)
        loss.backward()

        # Optimizer step (triggers All-Reduce over RDMA!)
        allreduce_start = time.time()
        optimizer.step()
        allreduce_time = (time.time() - allreduce_start) * 1000  # ms

        iteration_time = (time.time() - start_time) * 1000  # ms

        # Print stats every 10 iterations (only rank 0)
        if rank == 0 and iteration % 10 == 0:
            print(f"Iteration {iteration:4d} | "
                  f"Loss: {loss.item():.4f} | "
                  f"AllReduce: {allreduce_time:.1f}ms | "
                  f"Total: {iteration_time:.1f}ms")
            print(f"  → All {world_size} servers exchanging ~{gradient_size_mb:.1f}MB gradients")
            print(f"  → Check switch for ECN/PFC activity!")
            print("")

    if rank == 0:
        print("=== Training Complete ===")
        print("Check your monitoring windows for ECN/PFC/CNP statistics!")

    # Cleanup
    dist.destroy_process_group()

if __name__ == "__main__":
    main()
