#!/bin/bash

echo "=== Checking Cisco Nexus Switch Buffer Configuration ==="
echo ""

SWITCH_IP="192.168.50.229"
SWITCH_USER="admin"
SWITCH_PASS="<PASSWORD>"

echo "=== 1. System QoS Configuration ==="
sshpass -p "${SWITCH_PASS}" ssh -o StrictHostKeyChecking=no ${SWITCH_USER}@${SWITCH_IP} "show system qos" 2>&1

echo ""
echo "=== 2. Network QoS Policy (Buffer Allocation) ==="
sshpass -p "${SWITCH_PASS}" ssh -o StrictHostKeyChecking=no ${SWITCH_USER}@${SWITCH_IP} "show policy-map type network-qos" 2>&1

echo ""
echo "=== 3. Hardware Buffer Information ==="
sshpass -p "${SWITCH_PASS}" ssh -o StrictHostKeyChecking=no ${SWITCH_USER}@${SWITCH_IP} "show hardware internal buffer info" 2>&1

echo ""
echo "=== 4. Detailed Interface Buffer Stats (Ethernet1/1/1) ==="
sshpass -p "${SWITCH_PASS}" ssh -o StrictHostKeyChecking=no ${SWITCH_USER}@${SWITCH_IP} "show queuing interface ethernet1/1/1" 2>&1

echo ""
echo "=== 5. Buffer Pool Details ==="
sshpass -p "${SWITCH_PASS}" ssh -o StrictHostKeyChecking=no ${SWITCH_USER}@${SWITCH_IP} "show hardware internal buffer detail" 2>&1 | head -100
