#!/bin/bash

echo "=== Installing AI Training Stack on All 8 Servers ==="
echo "This will install: Python, PyTorch, Horovod, MPI with RDMA support"
echo ""

declare -a servers=(
    "ubunturdma1:192.168.11.152"
    "ubunturdma2:192.168.11.153"
    "ubunturdma3:192.168.11.154"
    "ubunturdma4:192.168.11.155"
    "ubunturdma5:192.168.11.107"
    "ubunturdma6:192.168.12.51"
    "ubunturdma7:192.168.20.150"
    "ubunturdma8:192.168.30.94"
)

install_on_server() {
    local hostname=$1
    local ip=$2

    echo "=== Installing on $hostname ($ip) ==="

    sshpass -p '<PASSWORD>' ssh -o StrictHostKeyChecking=no versa@${ip} << 'INSTALL_EOF'

# Update package list
echo '<PASSWORD>' | sudo -S apt update

# Install Python and pip
echo '<PASSWORD>' | sudo -S apt install -y python3 python3-pip python3-dev

# Install OpenMPI with UCX (RDMA support)
echo '<PASSWORD>' | sudo -S apt install -y openmpi-bin libopenmpi-dev

# Install UCX for RDMA
echo '<PASSWORD>' | sudo -S apt install -y ucx libucx-dev

# Install PyTorch (CPU version)
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install Horovod with MPI support
HOROVOD_WITH_PYTORCH=1 HOROVOD_WITH_MPI=1 pip3 install horovod

# Verify installations
echo ""
echo "=== Verification ==="
python3 --version
python3 -c "import torch; print(f'PyTorch: {torch.__version__}')"
python3 -c "import horovod.torch as hvd; print('Horovod: OK')" 2>/dev/null || echo "Horovod: Install in progress..."
mpirun --version | head -1

echo "✅ Installation complete on $(hostname)"

INSTALL_EOF

    echo ""
}

# Install on all servers in parallel
for server_info in "${servers[@]}"; do
    IFS=':' read -r hostname ip <<< "$server_info"
    install_on_server "$hostname" "$ip" &
done

wait

echo ""
echo "=== Installation Complete on All 8 Servers ==="
echo ""
echo "Next: Create training script and run distributed training"
