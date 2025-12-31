#!/bin/bash

#############################################
# Enable PFC with Sudo Password Handling
# Automated for all 8 servers - ens192 only
#############################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

USER_PASS="Versa@123!!"
IFACE="ens192"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Enable PFC on ens192 - All 8 Servers${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname <<< "$server_entry"

    echo ""
    echo -e "${BLUE}>>> Configuring $hostname ($ip)${NC}"
    echo ""

    # Create comprehensive expect script for this server
    cat > /tmp/pfc_${hostname}.exp << EOFEXP
#!/usr/bin/expect -f
set timeout 120

proc run_sudo_cmd {ip pass cmd description} {
    puts "\033[0;36m[CMD] \$description\033[0m"
    spawn ssh -o StrictHostKeyChecking=no versa@\$ip "\$cmd"
    expect {
        "password:" {
            send "\$pass\\r"
            exp_continue
        }
        eof
    }
}

# Step 1: Install lldpad
puts "\033[1;33mStep 1: Installing lldpad...\033[0m"
run_sudo_cmd "$ip" "$USER_PASS" "echo '$USER_PASS' | sudo -S apt-get update -qq && echo '$USER_PASS' | sudo -S apt-get install -y lldpad" "apt-get install lldpad"
puts "\033[0;32m✓ lldpad installed\033[0m\n"

# Step 2: Start lldpad
puts "\033[1;33mStep 2: Starting lldpad service...\033[0m"
run_sudo_cmd "$ip" "$USER_PASS" "echo '$USER_PASS' | sudo -S systemctl start lldpad" "systemctl start lldpad"
run_sudo_cmd "$ip" "$USER_PASS" "echo '$USER_PASS' | sudo -S systemctl enable lldpad" "systemctl enable lldpad"
puts "\033[0;32m✓ lldpad service started\033[0m\n"

# Step 3: Enable PFC
puts "\033[1;33mStep 3: Enabling PFC on $IFACE (Priority 3)...\033[0m"
run_sudo_cmd "$ip" "$USER_PASS" "echo '$USER_PASS' | sudo -S lldptool -T -i $IFACE -V PFC enableTx=yes" "lldptool enable PFC TX"
run_sudo_cmd "$ip" "$USER_PASS" "echo '$USER_PASS' | sudo -S lldptool -i $IFACE -T -V PFC -c enabled=0,0,0,1,0,0,0,0" "lldptool set PFC priority 3"
puts "\033[0;32m✓ PFC enabled on priority 3\033[0m\n"

# Step 4: Configure LLDP
puts "\033[1;33mStep 4: Configuring LLDP...\033[0m"
run_sudo_cmd "$ip" "$USER_PASS" "echo '$USER_PASS' | sudo -S lldptool set-lldp -i $IFACE adminStatus=rxtx" "lldptool set admin status"
puts "\033[0;32m✓ LLDP configured\033[0m\n"

# Step 5: Verify
puts "\033[1;33mStep 5: Verifying configuration...\033[0m"
spawn ssh -o StrictHostKeyChecking=no versa@$ip "echo '$USER_PASS' | sudo -S ethtool -a $IFACE"
expect {
    "password:" {
        send "$USER_PASS\\r"
        exp_continue
    }
    eof
}

puts "\033[0;32m✓ $hostname configuration complete!\033[0m"
puts "\033[0;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
EOFEXP

    chmod +x /tmp/pfc_${hostname}.exp
    expect /tmp/pfc_${hostname}.exp
    rm -f /tmp/pfc_${hostname}.exp

    sleep 1
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Final Verification - All Servers${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

for server_entry in "${SERVERS[@]}"; do
    IFS=':' read -r ip hostname <<< "$server_entry"

    echo -e "${CYAN}$hostname ($ip) - $IFACE:${NC}"

    cat > /tmp/verify_${hostname}.exp << EOFEXP2
#!/usr/bin/expect -f
set timeout 10
spawn ssh -o StrictHostKeyChecking=no versa@$ip "echo '$USER_PASS' | sudo -S ethtool -a $IFACE"
expect {
    "password:" {
        send "$USER_PASS\\r"
        exp_continue
    }
    eof
}
EOFEXP2

    chmod +x /tmp/verify_${hostname}.exp
    expect /tmp/verify_${hostname}.exp 2>&1 | grep -E "Pause parameters|RX:|TX:"
    rm -f /tmp/verify_${hostname}.exp

    echo ""
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary of Commands Executed${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "On each server, the following was executed:"
echo ""
echo "  1. echo 'Versa@123!!' | sudo -S apt-get update && apt-get install -y lldpad"
echo "  2. echo 'Versa@123!!' | sudo -S systemctl start lldpad"
echo "  3. echo 'Versa@123!!' | sudo -S systemctl enable lldpad"
echo "  4. echo 'Versa@123!!' | sudo -S lldptool -T -i ens192 -V PFC enableTx=yes"
echo "  5. echo 'Versa@123!!' | sudo -S lldptool -i ens192 -T -V PFC -c enabled=0,0,0,1,0,0,0,0"
echo "  6. echo 'Versa@123!!' | sudo -S lldptool set-lldp -i ens192 adminStatus=rxtx"
echo "  7. echo 'Versa@123!!' | sudo -S ethtool -a ens192"
echo ""
echo -e "${GREEN}✓ PFC configuration complete on all 8 servers!${NC}"
echo ""
echo -e "${YELLOW}Next: Test and verify on switch${NC}"
echo ""
