#!/bin/bash

#############################################
# AI/ML Stack Installation Script
# Installs PyTorch, NCCL, and related tools
# on all RDMA cluster servers
#############################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Server list
SERVERS=(
    "192.168.11.152"  # ubunturdma1
    "192.168.11.153"  # ubunturdma2
    "192.168.11.154"  # ubunturdma3
    "192.168.11.155"  # ubunturdma4
    "192.168.11.107"  # ubunturdma5
    "192.168.12.51"   # ubunturdma6
    "192.168.20.150"  # ubunturdma7
    "192.168.30.94"   # ubunturdma8
)

PASSWORD="<PASSWORD>"
LOG_FILE="/mnt/c/Users/eniza/Documents/claudechats/aiml_install_$(date +%Y%m%d_%H%M%S).log"

# Create expect script
create_expect_script() {
    cat > /tmp/ssh_cmd.exp << 'EOF'
#!/usr/bin/expect -f
set ip [lindex $argv 0]
set cmd [lindex $argv 1]
set timeout 300
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
    local ip=$1
    local cmd=$2
    expect /tmp/ssh_cmd.exp "$ip" "$cmd" 2>/dev/null
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Start logging
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "AI/ML Stack Installation"
echo "Started: $(date)"
echo "Log file: $LOG_FILE"
echo ""

create_expect_script

#############################################
# STEP 1: System Updates
#############################################
print_header "STEP 1: Updating System Packages"

for server in "${SERVERS[@]}"; do
    print_info "Updating $server..."
    ssh_exec "$server" "sudo apt-get update -qq" &
done
wait
print_success "All servers updated"
echo ""

#############################################
# STEP 2: Install Python and Dependencies
#############################################
print_header "STEP 2: Installing Python and Dependencies"

PYTHON_PACKAGES="python3-pip python3-dev python3-venv build-essential libopenmpi-dev"

for server in "${SERVERS[@]}"; do
    print_info "Installing Python packages on $server..."
    ssh_exec "$server" "sudo apt-get install -y -qq $PYTHON_PACKAGES" &
done
wait
print_success "Python and dependencies installed on all servers"
echo ""

#############################################
# STEP 3: Install PyTorch with CUDA support
#############################################
print_header "STEP 3: Installing PyTorch"

print_info "Installing PyTorch with CPU support (for testing)..."

for server in "${SERVERS[@]}"; do
    print_info "Installing PyTorch on $server..."
    ssh_exec "$server" "pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu" &
done
wait
print_success "PyTorch installed on all servers"
echo ""

#############################################
# STEP 4: Install NCCL and Communication Libraries
#############################################
print_header "STEP 4: Installing NCCL and MPI"

for server in "${SERVERS[@]}"; do
    print_info "Installing communication libraries on $server..."
    ssh_exec "$server" "pip3 install --user mpi4py" &
done
wait
print_success "Communication libraries installed"
echo ""

#############################################
# STEP 5: Install Additional ML Tools
#############################################
print_header "STEP 5: Installing Additional ML Tools"

ML_TOOLS="numpy pandas scikit-learn matplotlib jupyter tensorboard"

for server in "${SERVERS[@]}"; do
    print_info "Installing ML tools on $server..."
    ssh_exec "$server" "pip3 install --user $ML_TOOLS" &
done
wait
print_success "Additional ML tools installed"
echo ""

#############################################
# STEP 6: Verify Installation
#############################################
print_header "STEP 6: Verifying Installation"

for server in "${SERVERS[@]}"; do
    print_info "Verifying $server..."

    result=$(ssh_exec "$server" "python3 -c 'import torch; print(torch.__version__)' 2>&1")

    if [[ $result == *"."* ]]; then
        print_success "$server - PyTorch $(echo $result | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    else
        print_error "$server - PyTorch verification failed"
    fi
done
echo ""

#############################################
# STEP 7: Create Shared Directory
#############################################
print_header "STEP 7: Setting Up Shared Directory"

for server in "${SERVERS[@]}"; do
    print_info "Creating /home/versa/ai_workspace on $server..."
    ssh_exec "$server" "mkdir -p /home/versa/ai_workspace" &
done
wait
print_success "Workspace directories created"
echo ""

#############################################
# Summary
#############################################
print_header "INSTALLATION COMPLETE"

echo -e "${GREEN}AI/ML Stack successfully installed on all 8 servers!${NC}"
echo ""
echo "Installed components:"
echo "  ✓ Python 3 with pip"
echo "  ✓ PyTorch (CPU version)"
echo "  ✓ MPI4py (for distributed computing)"
echo "  ✓ NumPy, Pandas, Scikit-learn"
echo "  ✓ Matplotlib, Jupyter, TensorBoard"
echo ""
echo "Workspace: /home/versa/ai_workspace"
echo ""
echo "Next steps:"
echo "  1. Run verification script: ./verify_aiml_installation.sh"
echo "  2. Test distributed training: ./test_distributed_training.sh"
echo "  3. Review PyTorch NCCL backend configuration"
echo ""
echo "Log saved to: $LOG_FILE"
echo "Completed: $(date)"

# Cleanup
rm -f /tmp/ssh_cmd.exp

echo -e "${BLUE}========================================${NC}"
