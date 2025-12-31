#!/bin/bash

#############################################
# Intensive Distributed Training
# Generates heavy RDMA traffic to stress
# network and trigger PFC/ECN
#############################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
DURATION=${1:-300}  # Default 5 minutes

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
        send "Versa@123!!\r"
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

print_header "Intensive Distributed Training - Network Stress Test"

echo ""
print_info "Configuration:"
echo "  World Size: $WORLD_SIZE nodes"
echo "  Training Duration: $DURATION seconds"
echo "  Model Size: Large (to generate traffic)"
echo "  Batch Size: 128 (high memory pressure)"
echo "  Purpose: Stress network and trigger PFC/ECN"
echo ""

#############################################
# Create intensive training script
#############################################

TRAINING_SCRIPT='
import os
import sys
import time
import torch
import torch.distributed as dist
import torch.nn as nn
import torch.optim as optim
from torch.nn.parallel import DistributedDataParallel as DDP
import socket

class LargeModel(nn.Module):
    """Large model to generate significant network traffic"""
    def __init__(self):
        super(LargeModel, self).__init__()
        # Large layers to create significant gradient traffic
        self.fc1 = nn.Linear(2048, 2048)
        self.fc2 = nn.Linear(2048, 2048)
        self.fc3 = nn.Linear(2048, 2048)
        self.fc4 = nn.Linear(2048, 2048)
        self.fc5 = nn.Linear(2048, 1024)
        self.fc6 = nn.Linear(1024, 512)
        self.fc7 = nn.Linear(512, 256)
        self.fc8 = nn.Linear(256, 10)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(0.5)

    def forward(self, x):
        x = self.relu(self.fc1(x))
        x = self.dropout(x)
        x = self.relu(self.fc2(x))
        x = self.dropout(x)
        x = self.relu(self.fc3(x))
        x = self.dropout(x)
        x = self.relu(self.fc4(x))
        x = self.relu(self.fc5(x))
        x = self.relu(self.fc6(x))
        x = self.relu(self.fc7(x))
        x = self.fc8(x)
        return x

def train(rank, world_size, master_addr, duration):
    """Intensive training to stress network"""

    hostname = socket.gethostname()
    print(f"[Rank {rank}] Starting on {hostname}")

    # Setup distributed
    os.environ["MASTER_ADDR"] = master_addr
    os.environ["MASTER_PORT"] = "29500"
    dist.init_process_group(backend="gloo", rank=rank, world_size=world_size)

    print(f"[Rank {rank}] Process group initialized")

    # Create large model
    model = LargeModel()
    ddp_model = DDP(model)

    # Count parameters
    total_params = sum(p.numel() for p in model.parameters())
    print(f"[Rank {rank}] Model size: {total_params:,} parameters ({total_params*4/1e6:.2f} MB)")

    loss_fn = nn.CrossEntropyLoss()
    optimizer = optim.SGD(ddp_model.parameters(), lr=0.01, momentum=0.9)

    # Large batch size for more traffic
    batch_size = 128
    input_size = 2048

    print(f"[Rank {rank}] Starting intensive training loop...")
    print(f"[Rank {rank}] Batch size: {batch_size}, Input size: {input_size}")

    start_time = time.time()
    iteration = 0

    while (time.time() - start_time) < duration:
        iteration += 1

        # Generate random data (large batches)
        inputs = torch.randn(batch_size, input_size)
        labels = torch.randint(0, 10, (batch_size,))

        # Forward pass
        optimizer.zero_grad()
        outputs = ddp_model(inputs)
        loss = loss_fn(outputs, labels)

        # Backward pass (generates gradient synchronization traffic)
        loss.backward()
        optimizer.step()

        # Periodic all-reduce to increase traffic
        if iteration % 10 == 0:
            tensor = torch.randn(10000)  # Large tensor
            dist.all_reduce(tensor, op=dist.ReduceOp.SUM)

        if rank == 0 and iteration % 10 == 0:
            elapsed = time.time() - start_time
            print(f"[Rank {rank}] Iteration {iteration} - Loss: {loss.item():.4f} - Elapsed: {elapsed:.1f}s")

    elapsed = time.time() - start_time
    print(f"[Rank {rank}] Completed {iteration} iterations in {elapsed:.1f} seconds")
    print(f"[Rank {rank}] Average: {iteration/elapsed:.2f} iterations/sec")

    dist.destroy_process_group()

if __name__ == "__main__":
    rank = int(sys.argv[1])
    world_size = int(sys.argv[2])
    master_addr = sys.argv[3]
    duration = int(sys.argv[4])

    train(rank, world_size, master_addr, duration)
'

#############################################
# Deploy training script
#############################################
print_info "Deploying intensive training script to all nodes..."

for server_entry in "${ALL_SERVERS[@]}"; do
    IFS=':' read -r mgmt_ip hostname rank <<< "$server_entry"
    ssh_exec "$mgmt_ip" "cat > /home/versa/ai_workspace/intensive_training.py << 'EOFPYTHON'
$TRAINING_SCRIPT
EOFPYTHON"
    print_success "Deployed to $hostname"
done

echo ""

#############################################
# Start training
#############################################
print_header "Starting Intensive Training - Network Stress Test"

echo ""
print_info "Launching training on all 8 nodes..."
print_info "Training will run for $DURATION seconds"
print_info "Monitor switch during this time for PFC/ECN activity"
echo ""

# Start all nodes
for server_entry in "${ALL_SERVERS[@]}"; do
    IFS=':' read -r mgmt_ip hostname rank <<< "$server_entry"

    if [ $rank -eq 0 ]; then
        print_info "Starting MASTER (rank $rank) on $hostname..."
    else
        print_info "Starting WORKER (rank $rank) on $hostname..."
    fi

    ssh_exec "$mgmt_ip" "cd /home/versa/ai_workspace && python3 intensive_training.py $rank $WORLD_SIZE $MASTER_IP $DURATION" &

    sleep 1
done

echo ""
print_success "All nodes launched!"
echo ""
print_info "Training in progress... (${DURATION}s)"
print_info "NOW is the time to check your switch for:"
echo "  - ECN marks"
echo "  - PFC frames"
echo "  - Queue depths"
echo "  - Interface counters"
echo ""

# Wait for completion
wait

echo ""
print_success "Intensive training completed!"
echo ""

#############################################
# Summary
#############################################
print_header "Training Complete"

echo ""
echo "Network stress test completed successfully!"
echo ""
echo "What to check on your switch:"
echo ""
echo "1. ECN Configuration:"
echo "   - ECN marking threshold"
echo "   - ECN marked packets count"
echo ""
echo "2. PFC (Priority Flow Control):"
echo "   - PFC enabled queues"
echo "   - PFC pause frames sent/received"
echo "   - PFC no-drop class"
echo ""
echo "3. Queue Statistics:"
echo "   - Queue depth/utilization"
echo "   - Dropped packets"
echo "   - Tail drops"
echo ""
echo "Check the network monitoring results for RDMA statistics."
echo ""

rm -f /tmp/ssh_cmd.exp

echo -e "${BLUE}========================================${NC}"
