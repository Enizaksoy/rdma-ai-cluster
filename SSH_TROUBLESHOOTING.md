# SSH Authentication Issues - Troubleshooting Guide

## Problem
Claude Code consistently fails to SSH to servers with "Permission denied" errors, even with correct credentials.

## Symptoms
- `sshpass -p 'Versa@123!!' ssh versa@192.168.11.152` fails with "Permission denied"
- SSH key authentication also fails
- Manual SSH from user's terminal works fine with same credentials

## Root Causes
1. **SSH rate limiting** - Too many failed attempts trigger temporary IP blocks
2. **Different SSH environment** - Claude Code runs in a different context than user's shell
3. **Credential caching issues** - Stale authentication attempts

## Solutions

### Solution 1: Use Bash with Background Execution
Instead of interactive SSH, use scripts that run on the server:

```bash
# Create script locally
cat > /tmp/remote_script.sh << 'EOF'
#!/bin/bash
# Commands to run on remote server
sudo apt-get install -y sshpass
pkill -9 -f esxi_stats_exporter.py
nohup python3 ~/esxi_stats_exporter.py > /tmp/esxi_stats_exporter.log 2>&1 &
EOF

# User copies and runs manually
```

### Solution 2: Pre-deployed Scripts
Deploy scripts to server ahead of time, then just trigger them:

```bash
# Pre-deploy (user does this once)
ssh versa@192.168.11.152 'cat > ~/fix_esxi.sh' << 'EOF'
#!/bin/bash
sudo apt-get install -y sshpass
pkill -9 -f esxi_stats_exporter.py
nohup python3 ~/esxi_stats_exporter.py > /tmp/esxi_stats_exporter.log 2>&1 &
EOF

# Later, just trigger it
ssh versa@192.168.11.152 'bash ~/fix_esxi.sh'
```

### Solution 3: HTTP/API-based Commands
For critical operations, use web APIs instead of SSH:
- Prometheus for metrics collection
- Grafana API for dashboard updates
- REST endpoints for server management

## Current Workaround
When SSH fails:
1. Create the script locally in `/tmp/`
2. Provide user with exact commands to copy/paste
3. User runs them manually on the server

## Future Prevention
1. **Always check SSH connectivity first** before attempting operations
2. **Batch commands** into single SSH session instead of multiple attempts
3. **Use expect scripts** for complex interactions
4. **Document manual fallback** for every automated operation

## Server Details
- Primary server: 192.168.11.152
- User: versa
- Password: Versa@123!!
- SSH key: /home/eniza/.ssh/id_ed25519_rdma_cluster

## Test SSH Before Operations
```bash
# Quick SSH test
timeout 5 ssh -o ConnectTimeout=5 versa@192.168.11.152 "echo 'SSH OK'" || echo "SSH FAILED"
```

## Status
- **Issue**: Persistent throughout 2026-01-04 session
- **Impact**: Unable to automate server operations
- **Workaround**: User runs commands manually
- **Action Needed**: Investigate why Claude Code SSH differs from user SSH environment
