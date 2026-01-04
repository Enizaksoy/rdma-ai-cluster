#!/bin/bash
# Discover RDMA IP addresses for all 8 servers

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

echo "==================================================================="
echo "  Discovering RDMA Interface IPs"
echo "==================================================================="
echo ""

for entry in "${SERVERS[@]}"; do
    IP="${entry%%:*}"
    NAME="${entry##*:}"

    echo "[$NAME - $IP]"

    # Get RDMA interface IPs (192.168.250.x and 192.168.251.x)
    RDMA_IPS=$(sshpass -p 'Versa@123!!' ssh -o StrictHostKeyChecking=no versa@$IP \
        "ip addr show | grep -E 'inet (192\.168\.250\.|192\.168\.251\.)' | awk '{print \$2}' | cut -d/ -f1" 2>/dev/null)

    if [ -n "$RDMA_IPS" ]; then
        echo "  RDMA IPs: $RDMA_IPS"
    else
        echo "  ERROR: Could not get RDMA IPs"
    fi
    echo ""
done

echo "==================================================================="
echo ""
echo "Based on ESXi topology (1-4 on ESXi1, 5-8 on ESXi2):"
echo "Recommended traffic flows:"
echo "  ubunturdma1 → ubunturdma5"
echo "  ubunturdma2 → ubunturdma6"
echo "  ubunturdma3 → ubunturdma7"
echo "  ubunturdma4 → ubunturdma8"
echo ""
