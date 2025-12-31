#!/bin/bash

#############################################
# AI/ML Stack Verification Script
# Verifies PyTorch and dependencies
#############################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVERS=(
    "192.168.11.152:ubunturdma1"
    "192.168.11.153:ubunturdma2"
    "192.168.11.154:ubunturdma3"
    "192.168.11.155:ubunturdma4"
    "192.168.11.107:ubunturdma5"
    "192.168.12.51:ubunturdma6"
    "192.168.20.150:ubunturdma7"
    "192.168.30.94:ubunturdma8"
)

create_expect_script() {
    cat > /tmp/ssh_cmd.exp << 'EOF'
#!/usr/bin/expect -f
set ip [lindex $argv 0]
set cmd [lindex $argv 1]
set timeout 30
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

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

create_expect_script

print_header "AI/ML Stack Verification"

echo ""
echo "Checking Python and PyTorch installation on all servers..."
echo ""

# Verification script to run on each server
VERIFY_SCRIPT='
import sys
print("Python:", sys.version.split()[0])

try:
    import torch
    print("PyTorch:", torch.__version__)
    print("CUDA Available:", torch.cuda.is_available())
    print("CPU Threads:", torch.get_num_threads())
except Exception as e:
    print("PyTorch: ERROR -", str(e))

try:
    import numpy as np
    print("NumPy:", np.__version__)
except:
    print("NumPy: Not installed")

try:
    import pandas as pd
    print("Pandas:", pd.__version__)
except:
    print("Pandas: Not installed")

try:
    from mpi4py import MPI
    print("MPI4Py: Installed")
except:
    print("MPI4Py: Not installed")
'

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname <<< "$server_entry"

    echo -e "${YELLOW}=== $hostname ($ip) ===${NC}"
    ssh_exec "$ip" "python3 -c '$VERIFY_SCRIPT'"
    echo ""
done

print_header "Verification Complete"

echo "All servers checked. Review output above."
echo ""

# Cleanup
rm -f /tmp/ssh_cmd.exp
