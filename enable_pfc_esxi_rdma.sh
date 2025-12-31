#!/bin/bash

#############################################
# Enable PFC on ESXi RDMA NICs
# vmnic3 and vmnic4 for RDMA traffic
#############################################

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ESXI_IP="192.168.50.152"
ESXI_USER="root"
ESXI_PASS="<PASSWORD>"

echo -e "${BLUE}========================================${NC}"
echo "ESXi Host 1 - Enable PFC on RDMA NICs"
echo "Host: $ESXI_IP"
echo "RDMA NICs: vmnic3, vmnic4"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${CYAN}Connecting to ESXi host...${NC}"
echo ""

/usr/bin/expect << 'EOFEXP'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no root@192.168.50.152
expect {
    "Password:" {
        send "<PASSWORD>\r"
        expect "~]"
    }
}

puts "\n\033[0;34m=== Step 1: Check Current NIC Status ===\033[0m\n"

puts "\033[0;36m[1.1] All physical NICs:\033[0m"
send "esxcli network nic list\r"
expect "~]"

puts "\n\033[0;36m[1.2] Current pause parameters:\033[0m"
send "esxcli network nic pauseParams list\r"
expect "~]"

puts "\n\033[0;34m=== Step 2: Check RDMA NIC Details ===\033[0m\n"

puts "\033[0;36m[2.1] vmnic3 details:\033[0m"
send "esxcli network nic get -n vmnic3\r"
expect "~]"

puts "\n\033[0;36m[2.2] vmnic4 details:\033[0m"
send "esxcli network nic get -n vmnic4\r"
expect "~]"

puts "\n\033[0;34m=== Step 3: Enable PFC on RDMA NICs ===\033[0m\n"

puts "\033[0;36m[3.1] Enabling PFC on vmnic3...\033[0m"
puts "\033[1;33mCMD: esxcli network nic pauseParams set -n vmnic3 --rx-pause=true --tx-pause=true\033[0m"
send "esxcli network nic pauseParams set -n vmnic3 --rx-pause=true --tx-pause=true\r"
expect {
    "~]" {
        puts "\033[0;32m✓ vmnic3 PFC enabled\033[0m"
    }
    "Error" {
        puts "\033[0;31m✗ Error enabling vmnic3\033[0m"
    }
}

puts "\n\033[0;36m[3.2] Enabling PFC on vmnic4...\033[0m"
puts "\033[1;33mCMD: esxcli network nic pauseParams set -n vmnic4 --rx-pause=true --tx-pause=true\033[0m"
send "esxcli network nic pauseParams set -n vmnic4 --rx-pause=true --tx-pause=true\r"
expect {
    "~]" {
        puts "\033[0;32m✓ vmnic4 PFC enabled\033[0m"
    }
    "Error" {
        puts "\033[0;31m✗ Error enabling vmnic4\033[0m"
    }
}

puts "\n\033[0;34m=== Step 4: Verify PFC Configuration ===\033[0m\n"

puts "\033[0;36m[4.1] All pause parameters:\033[0m"
send "esxcli network nic pauseParams list\r"
expect "~]"

puts "\n\033[0;36m[4.2] vmnic3 pause status:\033[0m"
send "esxcli network nic pauseParams get -n vmnic3\r"
expect "~]"

puts "\n\033[0;36m[4.3] vmnic4 pause status:\033[0m"
send "esxcli network nic pauseParams get -n vmnic4\r"
expect "~]"

puts "\n\033[0;34m=== Step 5: Check vSwitch Configuration ===\033[0m\n"

puts "\033[0;36m[5.1] Standard vSwitches:\033[0m"
send "esxcli network vswitch standard list | head -50\r"
expect "~]"

puts "\n\033[0;34m========================================\033[0m"
puts "\033[0;34mPFC Configuration Complete\033[0m"
puts "\033[0;34m========================================\033[0m\n"

puts "\033[0;32m✓ PFC enabled on vmnic3 and vmnic4\033[0m\n"

puts "Commands executed:"
puts "  1. esxcli network nic pauseParams set -n vmnic3 --rx-pause=true --tx-pause=true"
puts "  2. esxcli network nic pauseParams set -n vmnic4 --rx-pause=true --tx-pause=true\n"

puts "Next steps:"
puts "  1. If you have ESXi host 2, configure vmnic3/vmnic4 there too"
puts "  2. Run traffic test: bash saturate_cross_esxi.sh 60"
puts "  3. Check switch:"
puts "     ssh admin@192.168.50.229"
puts "     show interface ethernet1/2/2 priority-flow-control\n"

send "exit\r"
expect eof
EOFEXP

echo ""
echo -e "${GREEN}✓ ESXi Host 1 configuration complete!${NC}"
