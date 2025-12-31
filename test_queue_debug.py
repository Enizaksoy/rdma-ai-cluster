#!/usr/bin/env python3
"""
Diagnostic script to debug queue statistics
"""

import requests
import json
from urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

SWITCH_IP = "192.168.50.229"
USERNAME = "admin"
PASSWORD = "Versa@123!!"
TEST_INTERFACE = "Ethernet1/2/2"

def send_nxapi_command(command, output_format="json"):
    """Send command to Nexus switch"""
    url = f"https://{SWITCH_IP}/ins"
    cmd_type = "cli_show" if output_format == "json" else "cli_show_ascii"

    payload = {
        "ins_api": {
            "version": "1.0",
            "type": cmd_type,
            "chunk": "0",
            "sid": "1",
            "input": command,
            "output_format": output_format
        }
    }

    try:
        response = requests.post(
            url,
            data=json.dumps(payload),
            headers={'content-type': 'application/json'},
            auth=(USERNAME, PASSWORD),
            verify=False,
            timeout=10
        )
        return response.json()
    except Exception as e:
        print(f"ERROR: {e}")
        return None

print("=" * 80)
print(f"QUEUE STATISTICS DEBUG - Testing interface: {TEST_INTERFACE}")
print("=" * 80)

# Test with JSON format
print("\n[1] Testing JSON format...")
result = send_nxapi_command(f"show queuing interface {TEST_INTERFACE}", "json")
if result:
    print("SUCCESS - JSON Response received")
    print("\nFull JSON structure:")
    print(json.dumps(result, indent=2))

    # Save JSON
    with open('queue_output_json.txt', 'w') as f:
        f.write(json.dumps(result, indent=2))
    print("\n✓ Saved to: queue_output_json.txt")
else:
    print("FAILED - No JSON response")

print("\n" + "=" * 80)

# Test with TEXT format
print("\n[2] Testing TEXT format...")
result = send_nxapi_command(f"show queuing interface {TEST_INTERFACE}", "text")
if result:
    print("SUCCESS - TEXT Response received")

    try:
        output_body = result['ins_api']['outputs']['output']['body']

        print("\n" + "=" * 80)
        print("RAW TEXT OUTPUT:")
        print("=" * 80)
        print(output_body)
        print("=" * 80)

        # Save text
        with open('queue_output_text.txt', 'w') as f:
            f.write(output_body)
        print("\n✓ Saved to: queue_output_text.txt")

        # Try to find QoS groups
        print("\n[3] Searching for QoS Group patterns...")
        if "QOS GROUP 0" in output_body:
            print("✓ Found QOS GROUP 0")
        if "QOS GROUP 3" in output_body:
            print("✓ Found QOS GROUP 3")
        if "CONTROL QOS GROUP" in output_body:
            print("✓ Found CONTROL QOS GROUP")

        # Look for Tx Pkts
        if "Tx Pkts" in output_body:
            print("✓ Found 'Tx Pkts' in output")
        if "Tx Byts" in output_body:
            print("✓ Found 'Tx Byts' in output")

    except Exception as e:
        print(f"ERROR parsing response: {e}")
else:
    print("FAILED - No TEXT response")

print("\n" + "=" * 80)
print("DIAGNOSTIC COMPLETE")
print("=" * 80)
print("\nPlease send me the contents of:")
print("  - queue_output_text.txt")
print("\nSo I can fix the parsing!")
print("\nPress any key to exit...")
input()
