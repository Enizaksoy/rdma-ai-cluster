#!/usr/bin/env python3
"""
Aggressive RDMA traffic generator to saturate links and trigger ECN marking.
Creates multiple parallel streams per connection to maximize queue depth.
"""

import subprocess
import time
import sys
from datetime import datetime, timedelta

# Server configuration
SERVERS = {
    "ubunturdma1": "192.168.11.152",
    "ubunturdma2": "192.168.11.153",
    "ubunturdma3": "192.168.11.154",
    "ubunturdma4": "192.168.11.155",
    "ubunturdma5": "192.168.11.156",
    "ubunturdma6": "192.168.11.157",
    "ubunturdma7": "192.168.11.158",
    "ubunturdma8": "192.168.11.159",
}

DEVICES = {
    "192.168.11.152": "rocep19s0",
    "192.168.11.153": "rocep11s0",
    "192.168.11.154": "rocep19s0",
    "192.168.11.155": "rocep11s0",
    "192.168.11.156": "rocep19s0",
    "192.168.11.157": "rocep11s0",
    "192.168.11.158": "rocep19s0",
    "192.168.11.159": "rocep11s0",
}

PASSWORD = "Versa@123!!"
DURATION = 1800  # 30 minutes

def ssh_exec(ip, cmd, background=False):
    """Execute SSH command"""
    if background:
        full_cmd = f"sshpass -p '{PASSWORD}' ssh -o StrictHostKeyChecking=no versa@{ip} '{cmd} </dev/null >/dev/null 2>&1 &'"
    else:
        full_cmd = f"sshpass -p '{PASSWORD}' ssh -o StrictHostKeyChecking=no versa@{ip} '{cmd}'"

    return subprocess.Popen(full_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

def cleanup_all():
    """Kill all existing ib_write_bw processes"""
    print("🧹 Cleaning up existing RDMA processes...")
    for ip in SERVERS.values():
        ssh_exec(ip, "pkill -9 ib_write_bw")
    time.sleep(2)

def start_aggressive_traffic():
    """
    Start aggressive RDMA traffic with multiple parallel streams.

    Strategy:
    - 4 parallel streams per connection (instead of 1)
    - Different message sizes to create burstier traffic
    - All 8 servers sending bidirectionally
    - This creates 32 total streams (8 connections × 4 streams each)
    """

    cleanup_all()

    print("🚀 Starting AGGRESSIVE RDMA traffic for ECN testing...")
    print(f"   Duration: {DURATION} seconds (30 minutes)")
    print(f"   Strategy: 4 parallel streams per connection")
    print(f"   Total streams: 32 (8 bidirectional × 4 parallel)")
    print()

    # Server configurations - Start listeners on all servers
    print("📡 Starting server listeners...")
    for name, ip in SERVERS.items():
        device = DEVICES[ip]
        # Start 4 listeners per server on different ports
        for port in [18515, 18516, 18517, 18518]:
            cmd = f"ib_write_bw -d {device} -D {DURATION} -p {port} --run_infinitely"
            ssh_exec(ip, cmd, background=True)
            print(f"   ✓ {name} ({ip}) listener on port {port}")

    time.sleep(3)

    # Connection flows - Create multiple parallel streams per pair
    # Each pair gets 4 streams with different message sizes for burstier traffic
    flows = [
        # ubunturdma1 <-> ubunturdma6 (Cross-ESXi)
        ("192.168.11.152", "rocep19s0", "192.168.251.116", [
            (18515, 65536),   # 64KB messages
            (18516, 32768),   # 32KB messages
            (18517, 16384),   # 16KB messages
            (18518, 8192),    # 8KB messages
        ]),

        # ubunturdma2 <-> ubunturdma5 (Cross-ESXi)
        ("192.168.11.153", "rocep11s0", "192.168.250.115", [
            (18515, 65536),
            (18516, 32768),
            (18517, 16384),
            (18518, 8192),
        ]),

        # ubunturdma3 <-> ubunturdma8 (Cross-ESXi)
        ("192.168.11.154", "rocep19s0", "192.168.249.118", [
            (18515, 65536),
            (18516, 32768),
            (18517, 16384),
            (18518, 8192),
        ]),

        # ubunturdma4 <-> ubunturdma7 (Cross-ESXi)
        ("192.168.11.155", "rocep11s0", "192.168.248.117", [
            (18515, 65536),
            (18516, 32768),
            (18517, 16384),
            (18518, 8192),
        ]),

        # ubunturdma5 <-> ubunturdma2 (Cross-ESXi - reverse)
        ("192.168.11.156", "rocep19s0", "192.168.246.102", [
            (18515, 65536),
            (18516, 32768),
            (18517, 16384),
            (18518, 8192),
        ]),

        # ubunturdma6 <-> ubunturdma1 (Cross-ESXi - reverse)
        ("192.168.11.157", "rocep11s0", "192.168.245.101", [
            (18515, 65536),
            (18516, 32768),
            (18517, 16384),
            (18518, 8192),
        ]),

        # ubunturdma7 <-> ubunturdma4 (Cross-ESXi - reverse)
        ("192.168.11.158", "rocep19s0", "192.168.244.104", [
            (18515, 65536),
            (18516, 32768),
            (18517, 16384),
            (18518, 8192),
        ]),

        # ubunturdma8 <-> ubunturdma3 (Cross-ESXi - reverse)
        ("192.168.11.159", "rocep11s0", "192.168.243.103", [
            (18515, 65536),
            (18516, 32768),
            (18517, 16384),
            (18518, 8192),
        ]),
    ]

    print("\n🔥 Starting client connections (4 parallel streams each)...")
    stream_count = 0
    for source_ip, device, dest_ip, streams in flows:
        source_name = [k for k, v in SERVERS.items() if v == source_ip][0]
        dest_name = [k for k, v in SERVERS.items() if dest_ip.startswith(v.rsplit('.', 1)[0])][0]

        for port, msg_size in streams:
            cmd = f"ib_write_bw -d {device} -D {DURATION} -p {port} -s {msg_size} --run_infinitely {dest_ip}"
            ssh_exec(source_ip, cmd, background=True)
            stream_count += 1
            print(f"   ✓ Stream {stream_count}: {source_name} → {dest_name} (port {port}, {msg_size//1024}KB msgs)")

    # Save status
    end_time = datetime.now() + timedelta(seconds=DURATION)
    status = {
        "running": True,
        "start_time": datetime.now().isoformat(),
        "end_time": end_time.isoformat(),
        "streams": stream_count,
        "strategy": "4 parallel streams per connection with varying message sizes"
    }

    with open("/tmp/rdma_aggressive_status.txt", "w") as f:
        for key, value in status.items():
            f.write(f"{key}: {value}\n")

    print(f"\n✅ AGGRESSIVE RDMA traffic started!")
    print(f"   Total active streams: {stream_count}")
    print(f"   End time: {end_time.strftime('%H:%M:%S')}")
    print(f"\n💡 Monitor ECN with:")
    print(f"   sudo tcpdump -i ens224 -nn -v 'udp port 18515' | grep -i ecn")

def stop_traffic():
    """Stop all RDMA traffic"""
    print("🛑 Stopping all RDMA traffic...")
    cleanup_all()

    with open("/tmp/rdma_aggressive_status.txt", "w") as f:
        f.write(f"running: False\n")
        f.write(f"stopped_at: {datetime.now().isoformat()}\n")

    print("✅ All RDMA traffic stopped")

def show_status():
    """Show current traffic status"""
    try:
        with open("/tmp/rdma_aggressive_status.txt", "r") as f:
            status = dict(line.strip().split(": ", 1) for line in f if ": " in line)

        if status.get("running") == "True":
            end_time = datetime.fromisoformat(status["end_time"])
            if datetime.now() < end_time:
                remaining = (end_time - datetime.now()).total_seconds()
                print(f"✅ AGGRESSIVE RDMA traffic RUNNING")
                print(f"   Streams: {status.get('streams', 'N/A')}")
                print(f"   Strategy: {status.get('strategy', 'N/A')}")
                print(f"   Started: {status['start_time']}")
                print(f"   Ends: {status['end_time']}")
                print(f"   Remaining: {int(remaining)} seconds")
            else:
                print("⏱️  Traffic session expired")
        else:
            print("⏹️  No active traffic session")
            if "stopped_at" in status:
                print(f"   Last stopped: {status['stopped_at']}")

    except FileNotFoundError:
        print("⏹️  No active traffic session")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: ./saturate_for_ecn.py {start|stop|status}")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "start":
        start_aggressive_traffic()
    elif cmd == "stop":
        stop_traffic()
    elif cmd == "status":
        show_status()
    else:
        print(f"Unknown command: {cmd}")
        print("Usage: ./saturate_for_ecn.py {start|stop|status}")
        sys.exit(1)
