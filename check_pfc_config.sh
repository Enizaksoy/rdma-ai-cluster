#!/bin/bash

#############################################
# Check PFC Configuration on Switch
# Diagnose why MMU drops are occurring
#############################################

SWITCH_IP="192.168.50.229"

cat > /tmp/switch_check.exp << 'EOF'
#!/usr/bin/expect -f
set timeout 30
spawn ssh -o StrictHostKeyChecking=no admin@192.168.50.229
expect "Password:"
send "<PASSWORD>\r"
expect "#"

# Check PFC configuration
send "show running-config | include priority-flow\r"
expect "#"

send "show interface ethernet1/2/2 priority-flow-control\r"
expect "#"

send "show interface ethernet1/2/1 priority-flow-control\r"
expect "#"

send "show interface ethernet1/1/1 priority-flow-control\r"
expect "#"

send "show interface ethernet1/1/2 priority-flow-control\r"
expect "#"

# Check QoS policy
send "show policy-map interface ethernet1/2/2\r"
expect "#"

# Check queue statistics
send "show queuing interface ethernet1/2/2\r"
expect "#"

send "show interface ethernet1/2/2 counters detailed\r"
expect "#"

send "exit\r"
expect eof
EOF

chmod +x /tmp/switch_check.exp
expect /tmp/switch_check.exp

rm -f /tmp/switch_check.exp
