#!/usr/bin/env python3
"""
RDMA Traffic Controller
Start/Stop 30-minute RDMA traffic generation across all 8 servers
"""

import subprocess
import sys
import time
import os
import signal
from datetime import datetime, timedelta

# Configuration
SERVERS = {
    "ubunturdma1": "192.168.11.152",
    "ubunturdma2": "192.168.11.153",
    "ubunturdma3": "192.168.11.154",
    "ubunturdma4": "192.168.11.155",
    "ubunturdma5": "192.168.11.107",
    "ubunturdma6": "192.168.12.51",
    "ubunturdma7": "192.168.20.150",
    "ubunturdma8": "192.168.30.94",
}

PASSWORD = "Versa@123!!"
DURATION_SECONDS = 1800  # 30 minutes
PID_FILE = "/tmp/rdma_traffic.pid"
STATUS_FILE = "/tmp/rdma_traffic_status.txt"

# ANSI colors
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
RED = '\033[0;31m'
CYAN = '\033[0;36m'
NC = '\033[0m'

def print_header(text):
    print(f"{BLUE}{'='*60}{NC}")
    print(f"{BLUE}{text:^60}{NC}")
    print(f"{BLUE}{'='*60}{NC}")

def print_info(text):
    print(f"{YELLOW}→ {text}{NC}")

def print_success(text):
    print(f"{GREEN}✓ {text}{NC}")

def print_error(text):
    print(f"{RED}✗ {text}{NC}")

def ssh_exec(ip, cmd):
    """Execute command via SSH using expect"""
    expect_script = f"""#!/usr/bin/expect -f
set timeout 300
spawn ssh -o StrictHostKeyChecking=no versa@{ip} "{cmd}"
expect {{
    "password:" {{
        send "{PASSWORD}\\r"
        exp_continue
    }}
    eof
}}
"""
    with open("/tmp/ssh_exec.exp", "w") as f:
        f.write(expect_script)
    os.chmod("/tmp/ssh_exec.exp", 0o755)

    return subprocess.Popen(["/tmp/ssh_exec.exp"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

def kill_all_rdma_traffic():
    """Stop all RDMA traffic on all servers"""
    print_info("Stopping RDMA traffic on all servers...")

    for name, ip in SERVERS.items():
        # More reliable kill: find PIDs explicitly and kill them
        cmd = "ps aux | grep ib_write_bw | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null; sleep 1"
        try:
            proc = ssh_exec(ip, cmd)
            proc.wait(timeout=10)
            print(f"  {name}: Stopped")
        except Exception as e:
            print(f"  {name}: {e}")

    # Remove PID and status files
    if os.path.exists(PID_FILE):
        os.remove(PID_FILE)
    if os.path.exists(STATUS_FILE):
        os.remove(STATUS_FILE)

    print_success("All RDMA traffic stopped")

def check_status():
    """Check if RDMA traffic is currently running"""
    if not os.path.exists(STATUS_FILE):
        print_error("No active RDMA traffic session")
        return False

    try:
        with open(STATUS_FILE, 'r') as f:
            lines = f.readlines()
            start_time = datetime.fromisoformat(lines[0].strip())
            end_time = datetime.fromisoformat(lines[1].strip())
            stream_count = int(lines[2].strip()) if len(lines) > 2 else 8

        now = datetime.now()

        if now > end_time:
            print_error("RDMA traffic session has expired")
            os.remove(STATUS_FILE)
            return False

        elapsed = now - start_time
        remaining = end_time - now

        print_header("RDMA Traffic Status")
        print(f"  Status: {GREEN}RUNNING (AGGRESSIVE MODE){NC}")
        print(f"  Active Streams: {stream_count}")
        print(f"  Started: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"  Will end: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"  Elapsed: {str(elapsed).split('.')[0]}")
        print(f"  Remaining: {str(remaining).split('.')[0]}")
        print(f"  Duration: {DURATION_SECONDS // 60} minutes")
        print()
        print_info("Monitor ECN with:")
        print(f"  sudo tcpdump -i ens224 -nn -v 'udp' | grep -i ecn")
        print()
        return True

    except Exception as e:
        print_error(f"Error reading status: {e}")
        return False

def start_traffic():
    """Start AGGRESSIVE RDMA traffic with multiple parallel streams for ECN testing"""

    # Check if already running
    if os.path.exists(STATUS_FILE):
        print_error("RDMA traffic is already running!")
        check_status()
        print_info("Use 'stop' to terminate it first")
        return 1

    print_header("RDMA Traffic Controller - AGGRESSIVE MODE")
    print()
    print_info("Configuration:")
    print(f"  Servers: {len(SERVERS)}")
    print(f"  Duration: {DURATION_SECONDS // 60} minutes ({DURATION_SECONDS} seconds)")
    print(f"  Traffic Pattern: 4 parallel streams per connection")
    print(f"  Message Sizes: 64KB, 32KB, 16KB, 8KB (bursty traffic)")
    print(f"  Total Streams: {len(SERVERS)} connections × 4 = {len(SERVERS) * 4} streams")
    print(f"  Purpose: Saturate queues to trigger ECN marking")
    print()

    # Kill any existing traffic first
    print_info("Cleaning up any existing RDMA processes...")
    kill_all_rdma_traffic()
    time.sleep(2)

    print_header("Starting AGGRESSIVE RDMA Traffic")

    # Device mapping
    devices = {
        "192.168.11.152": "rocep19s0",  # ubunturdma1
        "192.168.11.153": "rocep11s0",  # ubunturdma2
        "192.168.11.154": "rocep19s0",  # ubunturdma3
        "192.168.11.155": "rocep11s0",  # ubunturdma4
        "192.168.11.107": "rocep11s0",  # ubunturdma5
        "192.168.12.51": "rocep11s0",   # ubunturdma6
        "192.168.20.150": "rocep11s0",  # ubunturdma7
        "192.168.30.94": "rocep11s0",   # ubunturdma8
    }

    # Start 4 server listeners per host (one per port)
    print_info("Starting RDMA server listeners (4 per host)...")
    server_procs = []
    ports = [18515, 18516, 18517, 18518]

    for name, ip in SERVERS.items():
        device = devices[ip]
        for port in ports:
            cmd = f"ib_write_bw -d {device} -D {DURATION_SECONDS} -p {port} --run_infinitely"
            proc = ssh_exec(ip, cmd)
            server_procs.append(proc)
            time.sleep(0.3)
        print(f"  {name} ({ip}): 4 listeners started (ports {ports})")

    print_success(f"All servers ready ({len(server_procs)} listeners)")
    time.sleep(5)

    # Start clients with 4 parallel streams per connection
    print_info("Starting RDMA clients (4 parallel streams each)...")
    client_procs = []
    stream_count = 0

    # Connection pairs with multiple streams (different message sizes for burstiness)
    # ESXi1 (servers 1-4) → ESXi2 (servers 5-8) for cross-host traffic
    connections = [
        # ESXi Host 1 → ESXi Host 2
        ("192.168.11.152", "rocep19s0", "192.168.250.115", "ubunturdma1→5"),  # Server 1→5
        ("192.168.11.153", "rocep11s0", "192.168.251.111", "ubunturdma2→6"),  # Server 2→6 (note: 6 shares IP with 1)
        ("192.168.11.154", "rocep19s0", "192.168.250.117", "ubunturdma3→7"),  # Server 3→7
        ("192.168.11.155", "rocep11s0", "192.168.251.118", "ubunturdma4→8"),  # Server 4→8

        # ESXi Host 2 → ESXi Host 1 (reverse flows)
        ("192.168.11.107", "rocep11s0", "192.168.251.111", "ubunturdma5→1"),  # Server 5→1
        ("192.168.12.51", "rocep11s0", "192.168.250.112", "ubunturdma6→2"),   # Server 6→2
        ("192.168.20.150", "rocep11s0", "192.168.251.113", "ubunturdma7→3"),  # Server 7→3
        ("192.168.30.94", "rocep11s0", "192.168.250.114", "ubunturdma8→4"),   # Server 8→4
    ]

    # Message sizes for each stream (creates bursty traffic pattern)
    stream_configs = [
        (18515, 65536, "64KB"),  # Large messages
        (18516, 32768, "32KB"),  # Medium-large messages
        (18517, 16384, "16KB"),  # Medium messages
        (18518, 8192, "8KB"),    # Small messages
    ]

    for source_ip, device, target_ip, label in connections:
        print(f"  {label}:")
        for port, msg_size, size_label in stream_configs:
            cmd = f"ib_write_bw -d {device} -D {DURATION_SECONDS} -p {port} -s {msg_size} --run_infinitely {target_ip}"
            proc = ssh_exec(source_ip, cmd)
            client_procs.append(proc)
            stream_count += 1
            print(f"    Stream {stream_count}: port {port}, {size_label} msgs")
            time.sleep(0.3)

    # Save status
    start_time = datetime.now()
    end_time = start_time + timedelta(seconds=DURATION_SECONDS)

    with open(STATUS_FILE, 'w') as f:
        f.write(f"{start_time.isoformat()}\n")
        f.write(f"{end_time.isoformat()}\n")
        f.write(f"{stream_count}\n")

    print()
    print_success(f"All {stream_count} streams launched!")
    print()
    print_header("AGGRESSIVE RDMA Traffic Active")
    print()
    print(f"  {GREEN}Status: RUNNING (AGGRESSIVE MODE){NC}")
    print(f"  Active Streams: {stream_count}")
    print(f"  Connections: {len(connections)} bidirectional")
    print(f"  Streams per Connection: 4 parallel")
    print(f"  Started: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Will end: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Duration: {DURATION_SECONDS // 60} minutes")
    print()
    print_info("ECN Testing:")
    print(f"  • This traffic should saturate queues and trigger ECN marking")
    print(f"  • Monitor with: sudo tcpdump -i ens224 -nn -v 'udp' | grep -i ecn")
    print()
    print_info("Switch Monitoring:")
    print("  • Grafana: http://192.168.11.152:3000")
    print("  • Nexus Dashboard: http://192.168.11.152:3000/d/nexus-switch-monitoring")
    print("  • Watch queue depths and PFC counters")
    print()
    print_info("Commands:")
    print(f"  • Check status: ./rdma_traffic_controller.py status")
    print(f"  • Stop traffic: ./rdma_traffic_controller.py stop")
    print()

    return 0

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} [start|stop|status]")
        print()
        print("Commands:")
        print("  start  - Start 30-minute RDMA traffic on all servers")
        print("  stop   - Stop all RDMA traffic immediately")
        print("  status - Check current traffic status")
        print()
        return 1

    command = sys.argv[1].lower()

    if command == "start":
        return start_traffic()

    elif command == "stop":
        print_header("Stopping RDMA Traffic")
        kill_all_rdma_traffic()
        return 0

    elif command == "status":
        check_status()
        return 0

    else:
        print_error(f"Unknown command: {command}")
        print(f"Use: {sys.argv[0]} [start|stop|status]")
        return 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print()
        print_info("Interrupted by user")
        print_info("Traffic is still running. Use 'stop' to terminate.")
        sys.exit(1)
