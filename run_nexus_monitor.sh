#!/bin/bash
# Nexus Interface Monitor - Quick Start Script

SWITCH_IP="192.168.50.229"
USERNAME="admin"
PASSWORD="Versa@123!!"
INTERFACES="Ethernet1/1/1-4 Ethernet1/2/1-4"
INTERVAL=1

echo "Starting Nexus Interface Monitor..."
echo "Switch: $SWITCH_IP"
echo "Interfaces: $INTERFACES"
echo "Press Ctrl+C to stop"
echo ""

python3 /mnt/c/Users/eniza/Documents/claudechats/nexus_monitor.py \
    --host "$SWITCH_IP" \
    --user "$USERNAME" \
    --password "$PASSWORD" \
    --interfaces $INTERFACES \
    --interval $INTERVAL
