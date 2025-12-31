#!/bin/bash

#############################################
# Enable Flow Control on Cisco Switch
# Required for PFC to work properly
#############################################

/usr/bin/expect << 'EOF'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no admin@192.168.50.229
expect "Password:"
send "<PASSWORD>\r"
expect "#"

puts "\n=== Enabling Flow Control on RDMA Interfaces ==="

send "configure terminal\r"
expect "(config)#"

puts "\nConfiguring Ethernet1/1/1..."
send "interface ethernet1/1/1\r"
expect "(config-if)#"
send "flowcontrol receive on\r"
expect "(config-if)#"
send "flowcontrol send on\r"
expect "(config-if)#"
send "exit\r"
expect "(config)#"

puts "\nConfiguring Ethernet1/1/2..."
send "interface ethernet1/1/2\r"
expect "(config-if)#"
send "flowcontrol receive on\r"
expect "(config-if)#"
send "flowcontrol send on\r"
expect "(config-if)#"
send "exit\r"
expect "(config)#"

puts "\nConfiguring Ethernet1/2/1..."
send "interface ethernet1/2/1\r"
expect "(config-if)#"
send "flowcontrol receive on\r"
expect "(config-if)#"
send "flowcontrol send on\r"
expect "(config-if)#"
send "exit\r"
expect "(config)#"

puts "\nConfiguring Ethernet1/2/2..."
send "interface ethernet1/2/2\r"
expect "(config-if)#"
send "flowcontrol receive on\r"
expect "(config-if)#"
send "flowcontrol send on\r"
expect "(config-if)#"
send "exit\r"
expect "(config)#"

send "exit\r"
expect "#"

puts "\n=== Saving Configuration ==="
send "copy running-config startup-config\r"
expect {
    "?" {
        send "\r"
        exp_continue
    }
    "#" {
        puts "\nConfiguration saved!"
    }
}

puts "\n=== Verifying Configuration ==="
send "show interface flowcontrol\r"
expect "#"

send "exit\r"
expect eof
EOF
