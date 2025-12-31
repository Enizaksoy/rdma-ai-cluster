#!/bin/bash

#############################################
# Install PyTorch (No Sudo Required)
# User-level installation on all 8 servers
#############################################

GREEN='\033[0;32m'
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

echo "Installing PyTorch on all 8 servers (user-level, no sudo)..."
echo ""

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname <<< "$server_entry"

    print_info "Installing on $hostname ($ip)..."

    # Create workspace
    ssh_exec "$ip" "mkdir -p /home/versa/ai_workspace" &

    # Install PyTorch and dependencies
    ssh_exec "$ip" "pip3 install --user --quiet torch numpy" &
done

wait

echo ""
print_success "PyTorch installation completed on all servers!"

rm -f /tmp/ssh_cmd.exp
