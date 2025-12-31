#!/bin/bash

echo "=== Installing Docker on All Ubuntu Servers ==="
echo ""

# Server IPs
declare -a servers=(
    "192.168.11.152"  # ubunturdma1
    "192.168.11.153"  # ubunturdma2
    "192.168.11.154"  # ubunturdma3
    "192.168.11.155"  # ubunturdma4
    "192.168.11.156"  # ubunturdma5
    "192.168.11.157"  # ubunturdma6
    "192.168.11.158"  # ubunturdma7
    "192.168.11.159"  # ubunturdma8
)

# Function to install Docker on one server
install_docker() {
    local ip=$1
    local num=$((${ip##*.} - 151))
    
    echo "=== Installing Docker on ubunturdma${num} ($ip) ==="
    
    expect << EOF
set timeout 180
spawn ssh -o StrictHostKeyChecking=no versa@${ip}
expect "password:"
send "<PASSWORD>\r"
expect "$ "

send "echo 'Starting Docker installation...'\r"
expect "$ "

send "echo '<PASSWORD>' | sudo -S apt update -y\r"
expect "$ "

send "echo '<PASSWORD>' | sudo -S apt install -y docker.io\r"
expect {
    "Do you want to continue?" {
        send "Y\r"
        exp_continue
    }
    "$ " {}
    timeout { puts "\nInstallation timeout"; expect "$ " }
}

send "echo '<PASSWORD>' | sudo -S systemctl start docker\r"
expect "$ "

send "echo '<PASSWORD>' | sudo -S systemctl enable docker\r"
expect "$ "

send "echo '<PASSWORD>' | sudo -S usermod -aG docker versa\r"
expect "$ "

send "sudo docker --version\r"
expect "$ "

send "echo 'Docker installation completed on ubunturdma${num}'\r"
expect "$ "

send "exit\r"
expect eof
EOF

    echo "Completed: ubunturdma${num}"
    echo ""
}

# Install on all servers in parallel
for ip in "${servers[@]}"; do
    install_docker "$ip" &
done

wait

echo ""
echo "=== Docker Installation Completed on All Servers ==="
echo ""
echo "To verify, run: sudo docker --version"
echo "To use without sudo, logout and login again"
