# Quick Reference - RDMA/RoCE Lab

## Start Aggressive RDMA Traffic (Generates ECN)
```bash
./rdma_traffic_controller.py start
```
- 32 parallel streams
- 30 minute duration
- Cross-ESXi: Servers 1-4 ↔ 5-8
- **Result:** ECN marking + PFC on internal fabric

## Stop All Traffic
```bash
./rdma_traffic_controller.py stop
```

## Check Traffic Status
```bash
./rdma_traffic_controller.py status
```

## Monitor ECN Packets
```bash
# Live packet capture (on any server)
ssh versa@192.168.11.152
sudo tcpdump -i ens224 -nn -v 'udp port 18515' | grep -E '(tos|ECN|CE)'
```

## Check Switch PFC (Run twice to see what's increasing)
```bash
ssh admin@192.168.50.229
show interface priority-flow-control
```

## Grafana Dashboard
http://192.168.11.152:3000/d/nexus-switch-monitoring

## Verify Exporter Has All ii Ports
```bash
curl -s http://192.168.11.152:9102/metrics | grep "nexus_pfc.*ii" | wc -l
```
Expected: **12** (6 ports × 2 metrics)

## Restart Exporter (if needed)
```bash
ssh versa@192.168.11.152
pkill -9 -f nexus_prometheus_exporter
nohup python3 ~/nexus_prometheus_exporter.py > /tmp/nexus_exporter.log 2>&1 &
```

## Key IPs
- Switch: 192.168.50.229
- Grafana: 192.168.11.152:3000
- Prometheus: 192.168.11.152:9090
- Exporter: 192.168.11.152:9102

## Password
`Versa@123!!`

## Active PFC Ports (During Traffic)
- ii1/1/5: ~3,200 PFC/sec
- ii1/1/6: ~3,100 PFC/sec
