#!/usr/bin/env python3
"""
Simple Distributed AI Training Script
Generates All-Reduce traffic to test RDMA network with ECN/PFC

This will create realistic AI training traffic patterns across all 8 servers
"""

import torch
import torch.nn as nn
import torch.optim as optim
import horovod.torch as hvd
import time
import numpy as np

# Initialize Horovod
hvd.init()

print(f"[Rank {hvd.rank()}/{hvd.size()}] Starting distributed training on {hvd.local_rank()}")

# Simple neural network (will generate ~100MB gradients per iteration)
class LargeModel(nn.Module):
    def __init__(self):
        super(LargeModel, self).__init__()
        # Large layers to generate significant gradient traffic
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

# Create model
model = LargeModel()

# Horovod: wrap optimizer with DistributedOptimizer
optimizer = optim.SGD(model.parameters(), lr=0.01)
optimizer = hvd.DistributedOptimizer(optimizer)

# Horovod: broadcast parameters & optimizer state
hvd.broadcast_parameters(model.state_dict(), root_rank=0)
hvd.broadcast_optimizer_state(optimizer, root_rank=0)

# Loss function
criterion = nn.CrossEntropyLoss()

# Generate dummy data
def generate_batch(batch_size=256):
    data = torch.randn(batch_size, 10000)
    labels = torch.randint(0, 10, (batch_size,))
    return data, labels

print(f"[Rank {hvd.rank()}] Model size: {sum(p.numel() for p in model.parameters())} parameters")
print(f"[Rank {hvd.rank()}] Gradient size: ~{sum(p.numel() * 4 for p in model.parameters()) / 1024 / 1024:.1f} MB")
print(f"[Rank {hvd.rank()}] Starting training loop...")
print("")

# Training loop
num_iterations = 1000  # Run for many iterations to generate sustained traffic
batch_size = 256

for iteration in range(num_iterations):
    start_time = time.time()

    # Generate batch
    data, labels = generate_batch(batch_size)

    # Forward pass
    optimizer.zero_grad()
    outputs = model(data)
    loss = criterion(outputs, labels)

    # Backward pass (compute gradients)
    loss.backward()

    # Optimizer step (triggers All-Reduce via Horovod over RDMA!)
    # This is where the network traffic happens!
    allreduce_start = time.time()
    optimizer.step()
    allreduce_time = (time.time() - allreduce_start) * 1000  # ms

    iteration_time = (time.time() - start_time) * 1000  # ms

    # Print stats every 10 iterations (only rank 0)
    if hvd.rank() == 0 and iteration % 10 == 0:
        print(f"Iteration {iteration:4d} | "
              f"Loss: {loss.item():.4f} | "
              f"AllReduce: {allreduce_time:.1f}ms | "
              f"Total: {iteration_time:.1f}ms")
        print(f"  → Network traffic: All {hvd.size()} servers exchanging ~{sum(p.numel() * 4 for p in model.parameters()) / 1024 / 1024:.1f}MB gradients")
        print(f"  → Check switch stats NOW for ECN/PFC activity!")
        print("")

print(f"[Rank {hvd.rank()}] Training complete! Check your switch statistics.")
