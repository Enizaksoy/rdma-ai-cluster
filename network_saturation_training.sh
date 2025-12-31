#!/bin/bash

#############################################
# Network Saturation AI Training
# Large-scale distributed training to saturate
# 10 Gbps switch interfaces
#############################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

MASTER_IP="192.168.251.111"
MASTER_MGMT="192.168.11.152"

declare -a ALL_SERVERS=(
    "192.168.11.152:ubunturdma1:0"
    "192.168.11.153:ubunturdma2:1"
    "192.168.11.154:ubunturdma3:2"
    "192.168.11.155:ubunturdma4:3"
    "192.168.11.107:ubunturdma5:4"
    "192.168.12.51:ubunturdma6:5"
    "192.168.20.150:ubunturdma7:6"
    "192.168.30.94:ubunturdma8:7"
)

WORLD_SIZE=8
DURATION=${1:-120}  # Default 2 minutes

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

create_expect_script() {
    cat > /tmp/ssh_cmd.exp << 'EOF'
#!/usr/bin/expect -f
set ip [lindex $argv 0]
set cmd [lindex $argv 1]
set timeout 600
spawn ssh -o StrictHostKeyChecking=no versa@$ip "$cmd"
expect {
    "password:" {
        send "<PASSWORD>\r"
        exp_continue
    }
    eof
}
EOF
    chmod +x /tmp/ssh_cmd.exp
}

ssh_exec() {
    expect /tmp/ssh_cmd.exp "$1" "$2" 2>/dev/null
}

create_expect_script

print_header "Network Saturation Training - AI Cluster Test"

echo ""
print_info "Training Configuration:"
echo "  Purpose: Saturate 10 Gbps switch interfaces"
echo "  Model: Very Large Neural Network (50M+ parameters)"
echo "  Batch Size: 256 (high memory & network load)"
echo "  World Size: 8 nodes"
echo "  Duration: $DURATION seconds"
echo "  Expected Traffic: 8-12 Gbps per node"
echo ""

#############################################
# Create intensive training script
#############################################

TRAINING_SCRIPT='
import os
import sys
import time
import socket
try:
    import torch
    import torch.distributed as dist
    import torch.nn as nn
    import torch.optim as optim
    from torch.nn.parallel import DistributedDataParallel as DDP
except ImportError:
    print("ERROR: PyTorch not installed!")
    print("Run: pip3 install --user torch")
    sys.exit(1)

class VeryLargeModel(nn.Module):
    """
    Extremely large model designed to generate massive network traffic
    ~50 million parameters = ~200 MB of gradients per iteration
    With 8 nodes, this creates ~1.6 GB of all-reduce traffic per iteration
    """
    def __init__(self):
        super(VeryLargeModel, self).__init__()

        # Very large fully connected layers
        # Each layer creates millions of parameters
        self.fc1 = nn.Linear(4096, 4096)  # 16M params
        self.fc2 = nn.Linear(4096, 4096)  # 16M params
        self.fc3 = nn.Linear(4096, 4096)  # 16M params
        self.fc4 = nn.Linear(4096, 2048)  # 8M params
        self.fc5 = nn.Linear(2048, 1024)  # 2M params
        self.fc6 = nn.Linear(1024, 512)
        self.fc7 = nn.Linear(512, 256)
        self.fc8 = nn.Linear(256, 10)

        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(0.3)

        # Count parameters
        total = sum(p.numel() for p in self.parameters())
        print(f"Model Parameters: {total:,} ({total*4/1e6:.1f} MB)")

    def forward(self, x):
        x = self.dropout(self.relu(self.fc1(x)))
        x = self.dropout(self.relu(self.fc2(x)))
        x = self.dropout(self.relu(self.fc3(x)))
        x = self.dropout(self.relu(self.fc4(x)))
        x = self.relu(self.fc5(x))
        x = self.relu(self.fc6(x))
        x = self.relu(self.fc7(x))
        x = self.fc8(x)
        return x

def train_intensive(rank, world_size, master_addr, duration):
    """
    Intensive training loop designed to saturate network
    """
    hostname = socket.gethostname()
    print(f"[Rank {rank}] Starting on {hostname}")
    print(f"[Rank {rank}] Target: Saturate 10 Gbps network interface")

    # Setup distributed
    os.environ["MASTER_ADDR"] = master_addr
    os.environ["MASTER_PORT"] = "29500"
    os.environ["GLOO_SOCKET_IFNAME"] = "ens224,ens192"  # Use RDMA interfaces

    print(f"[Rank {rank}] Initializing process group...")
    dist.init_process_group(backend="gloo", rank=rank, world_size=world_size)
    print(f"[Rank {rank}] Process group ready")

    # Create very large model
    print(f"[Rank {rank}] Creating large model...")
    model = VeryLargeModel()
    ddp_model = DDP(model)

    # Optimizer
    optimizer = optim.SGD(ddp_model.parameters(), lr=0.01, momentum=0.9)
    loss_fn = nn.CrossEntropyLoss()

    # Very large batch for maximum memory and network pressure
    batch_size = 256
    input_size = 4096

    print(f"[Rank {rank}] Configuration:")
    print(f"  Batch Size: {batch_size}")
    print(f"  Input Size: {input_size}")
    print(f"  Expected gradient size: ~200 MB")
    print(f"  All-reduce traffic: ~1.6 GB per iteration")
    print("")

    start_time = time.time()
    iteration = 0
    total_bytes_allreduce = 0

    print(f"[Rank {rank}] Starting training loop...")
    print(f"[Rank {rank}] >>> MONITOR YOUR SWITCH NOW <<<")
    print("")

    while (time.time() - start_time) < duration:
        iteration += 1

        # Generate large batch
        inputs = torch.randn(batch_size, input_size)
        labels = torch.randint(0, 10, (batch_size,))

        # Forward pass
        optimizer.zero_grad()
        outputs = ddp_model(inputs)
        loss = loss_fn(outputs, labels)

        # Backward pass - triggers gradient all-reduce
        loss.backward()
        optimizer.step()

        # Additional all-reduce operations to increase traffic
        if iteration % 5 == 0:
            # Extra large tensor all-reduce
            extra_tensor = torch.randn(50000)  # 200 KB
            dist.all_reduce(extra_tensor, op=dist.ReduceOp.SUM)
            total_bytes_allreduce += 200000

        if rank == 0 and iteration % 10 == 0:
            elapsed = time.time() - start_time
            rate = iteration / elapsed
            print(f"[Rank {rank}] Iter {iteration} | Loss: {loss.item():.4f} | "
                  f"Rate: {rate:.2f} iter/s | Time: {elapsed:.1f}s")

    elapsed = time.time() - start_time
    print("")
    print(f"[Rank {rank}] Training complete!")
    print(f"[Rank {rank}] Total iterations: {iteration}")
    print(f"[Rank {rank}] Duration: {elapsed:.1f} seconds")
    print(f"[Rank {rank}] Throughput: {iteration/elapsed:.2f} iterations/sec")
    print(f"[Rank {rank}] Estimated network traffic: "
          f"{iteration * 1.6:.1f} GB total (~{iteration * 1.6 / elapsed:.2f} GB/s avg)")

    dist.destroy_process_group()

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python3 script.py <rank> <world_size> <master_addr> <duration>")
        sys.exit(1)

    rank = int(sys.argv[1])
    world_size = int(sys.argv[2])
    master_addr = sys.argv[3]
    duration = int(sys.argv[4])

    try:
        train_intensive(rank, world_size, master_addr, duration)
    except Exception as e:
        print(f"[Rank {rank}] ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
'

#############################################
# Deploy training script
#############################################
print_info "Deploying training script to all nodes..."

for server_entry in "${ALL_SERVERS[@]}"; do
    IFS=':' read -r mgmt_ip hostname rank <<< "$server_entry"

    ssh_exec "$mgmt_ip" "cat > /home/versa/ai_workspace/saturation_training.py << 'EOFPYTHON'
$TRAINING_SCRIPT
EOFPYTHON"

    print_success "Deployed to $hostname"
done

echo ""

#############################################
# Start training
#############################################
print_header "Starting Network Saturation Training"

echo ""
print_info "Launching on all 8 nodes..."
echo ""
print_info ">>> MONITOR YOUR SWITCH NOW <<<"
echo "  - Interface counters (should see 8-12 Gbps)"
echo "  - PFC pause frames"
echo "  - Queue depths"
echo "  - ECN marks"
echo ""

# Launch all nodes
for server_entry in "${ALL_SERVERS[@]}"; do
    IFS=':' read -r mgmt_ip hostname rank <<< "$server_entry"

    if [ $rank -eq 0 ]; then
        print_info "Starting MASTER (rank $rank) on $hostname..."
    else
        print_info "Starting WORKER (rank $rank) on $hostname..."
    fi

    ssh_exec "$mgmt_ip" "cd /home/versa/ai_workspace && python3 saturation_training.py $rank $WORLD_SIZE $MASTER_IP $DURATION" &

    sleep 1
done

echo ""
print_success "All nodes launched!"
echo ""
print_info "Training for ${DURATION} seconds..."
print_info "Expected switch interface utilization: 80-100%"
echo ""

# Wait for completion
wait

echo ""
print_header "Training Complete"

echo ""
print_success "Network saturation test completed!"
echo ""
echo "What you should have seen on switch:"
echo "  • Interface throughput: 8-12 Gbps per port"
echo "  • High queue utilization"
echo "  • Possible PFC pause frames"
echo "  • ECN marking (if configured)"
echo ""

rm -f /tmp/ssh_cmd.exp

print_header "Test Finished"
