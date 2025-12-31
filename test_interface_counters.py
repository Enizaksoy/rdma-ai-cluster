#!/usr/bin/env python3
"""
Test to see what interface counters look like
"""

import requests
import json
import time
from urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

SWITCH_IP = "192.168.50.229"
USERNAME = "admin"
PASSWORD = "<PASSWORD>"
TEST_INTERFACE = "Ethernet1/1/2"

def send_nxapi_command(command):
    url = f"https://{SWITCH_IP}/ins"
    payload = {
        "ins_api": {
            "version": "1.0",
            "type": "cli_show",
            "chunk": "0",
            "sid": "1",
            "input": command,
            "output_format": "json"
        }
    }

    try:
        response = requests.post(
            url,
            data=json.dumps(payload),
            headers={'content-type': 'application/json'},
            auth=(USERNAME, PASSWORD),
            verify=False,
            timeout=5
        )
        return response.json()
    except Exception as e:
        print(f"ERROR: {e}")
        return None

print("=" * 80)
print(f"Testing interface counters for {TEST_INTERFACE}")
print("=" * 80)

# Get interface stats twice with 2 second gap
print("\n[1] Reading counters at T=0...")
result1 = send_nxapi_command(f"show interface {TEST_INTERFACE}")
if result1:
    body1 = result1['ins_api']['outputs']['output']['body']
    iface1 = body1.get('TABLE_interface', {}).get('ROW_interface', {})

    print(f"eth_inbytes:  {iface1.get('eth_inbytes', 'N/A')}")
    print(f"eth_outbytes: {iface1.get('eth_outbytes', 'N/A')}")
    print(f"eth_inucast:  {iface1.get('eth_inucast', 'N/A')}")
    print(f"eth_outucast: {iface1.get('eth_outucast', 'N/A')}")

print("\n[2] Waiting 2 seconds...")
time.sleep(2)

print("\n[3] Reading counters at T=2...")
result2 = send_nxapi_command(f"show interface {TEST_INTERFACE}")
if result2:
    body2 = result2['ins_api']['outputs']['output']['body']
    iface2 = body2.get('TABLE_interface', {}).get('ROW_interface', {})

    print(f"eth_inbytes:  {iface2.get('eth_inbytes', 'N/A')}")
    print(f"eth_outbytes: {iface2.get('eth_outbytes', 'N/A')}")
    print(f"eth_inucast:  {iface2.get('eth_inucast', 'N/A')}")
    print(f"eth_outucast: {iface2.get('eth_outucast', 'N/A')}")

print("\n[4] Calculating delta...")
if result1 and result2:
    in_delta = int(iface2.get('eth_inbytes', 0)) - int(iface1.get('eth_inbytes', 0))
    out_delta = int(iface2.get('eth_outbytes', 0)) - int(iface1.get('eth_outbytes', 0))

    print(f"eth_inbytes delta:  {in_delta} bytes")
    print(f"eth_outbytes delta: {out_delta} bytes")

    rx_mbps = (in_delta * 8) / (2 * 1_000_000)
    tx_mbps = (out_delta * 8) / (2 * 1_000_000)

    print(f"\nCalculated bandwidth:")
    print(f"RX: {rx_mbps:.2f} Mbps")
    print(f"TX: {tx_mbps:.2f} Mbps")

print("\n" + "=" * 80)
print("Run this while traffic is flowing!")
print("If deltas are 0, interface counters aren't working for this traffic type")
print("=" * 80)

input("\nPress Enter to exit...")
