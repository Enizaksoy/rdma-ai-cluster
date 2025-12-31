# Versa FlexVNF CLI Commands Reference

## Basic Show Commands

### Interface Commands
- `show interfaces brief` - Display operational status of all interfaces
- `show interfaces detail [interface-name]` - Display link speed, duplex, packet stats, errors
- `show interfaces port statistics brief` - Show RX/TX packets, bytes, errors across all ports
- `show configuration interfaces [interface-name]` - Show interface configuration
- `show configuration interfaces [interface-name] | nomore` - Show full config without pagination

### System Commands
- `show system trial-info` - Display trial license information
- `show system package-info` - Show installed package information
- `show system status` - Display system status
- `show coredumps` - Show core dump files

### Session Commands
- `show orgs org [organization-name] sessions sdwan brief` - Show SD-WAN sessions
- `show vsf per-thread nfp stats summary` - Show sessions per worker thread (in VSM)

## Configuration Commands

### System Configuration
- `request system load-default` - Reset to factory default configuration
- `request erase config-file` - Delete configuration from device
- `request system package upgrade` - Upgrade system package
- `request system rollback` - Rollback to previous version
- `request system isolate-cpu status` - Check CPU isolation status
- `request system isolate-cpu enable` - Enable CPU isolation

### Interface Configuration
- `set orgs org-services [org-name] application-identification application-generic-options offload enabled` - Enable application offload
- `set system service-options poller-count [number]` - Adjust poller CPU allocation

### CoS/QoS Commands
- `show class-of-services interfaces brief` - Show TX packets dropped and queue stats
- `show class-of-services interfaces detail [interface-name]` - Detailed CoS statistics
- `show orgs org-services [org-name] class-of-service qos-policies` - QoS rule hits and drops
- `show orgs org-services [org-name] class-of-service app-qos-policies` - Application QoS stats
- `show configuration system session tcp-adjust-mss` - Check TCP MSS adjustment
- `show configuration orgs org-services [org-name] options override-df-bit` - Check DF bit override

## Advanced Diagnostics (VSM Shell)

### Enter VSM Shell
- `vsh connect vsmd` - Enter VSM shell for advanced diagnostics

### VSM Commands (run inside VSM)
- `show vsm cpu info` - Display CPU allocation
- `show vsm anchor core map` - Map traffic classes to CPU cores
- `show vsm cq stats` - Queue statistics and data distribution
- `show vsm statistics datapath` - Fragments, reassembled packets, punted packets
- `show vsm statistics dropped` - Comprehensive error statistics
- `show vsm statistics thrm detail` - Detailed poller thread statistics
- `show vsf tunnel stats` - Tunnel encapsulation statistics

## Network Testing Commands
- `ping [ip-address] rapid enable` - Rapid ping testing
  - Options: count, df-bit, interface, packet-size, routing-instance, source
- `tcpdump vni-[x]/[x] filter [remote-host]` - Capture packets on WAN interfaces

## System Monitoring
- `htop` - Real-time CPU and memory usage
- `top -H` - Thread-level CPU utilization
- `top -o %MEM` - Processes sorted by memory
- `top -o %CPU` - Processes sorted by CPU

## Staging and Activation
- `sudo /opt/versa/scripts/staging.py [options]` - Activate VOS device from CLI
- `vsh show-staging-params` - Display supported staging parameters

## Provider/Controller Commands
- `set provider appliances appliance [controller-uuid] staging-controller` - Configure staging Controller
- `show devices device [device-name] config system sd-wan site provider-org` - Query provider org
- `show devices device [controller-name] config orgs org-services [org-name] ipsec vpn-profile vpn-type controller-staging-sdwan` - List VPN profiles

## CLI Navigation
- `cli` - Enter CLI mode from shell
- `exit` - Exit current mode
- `?` - Show available commands
- `[command] ?` - Show command options
- `| nomore` - Suppress pagination in output
- `| match [pattern]` - Filter output by pattern
- `| except [pattern]` - Exclude lines matching pattern
- `| count` - Count lines in output

## Configuration Mode Commands
- `configure` - Enter configuration mode
- `commit` - Commit configuration changes
- `rollback` - Discard configuration changes
- `compare` - Compare candidate and running config
- `show configuration` - Show running configuration

## Common Usage Examples

### Check interface status
```
admin@device-cli> show interfaces brief
admin@device-cli> show interfaces detail vni-0/2
```

### View interface configuration
```
admin@device-cli> show configuration interfaces vni-0/2 | nomore
```

### Troubleshoot sessions
```
admin@device-cli> show orgs org Tenant-Common sessions sdwan brief
```

### Monitor system resources
```
admin@device-cli> show vsm cpu info
admin@device-cli> vsh connect vsmd
vsm> show vsm statistics dropped
```

### Network testing
```
admin@device-cli> ping 8.8.8.8 rapid enable count 100
admin@device-cli> tcpdump vni-0/2 filter 192.168.1.1
```

## CGNAT Configuration

### Show CGNAT Configuration
- `show configuration orgs org-services [org-name] cgnat | display set` - Show CGNAT config in set format
- `show configuration orgs org-services [org-name] cgnat pools` - Show CGNAT pools
- `show configuration orgs org-services [org-name] cgnat rules` - Show CGNAT rules
- `show configuration orgs org-services [org-name] cgnat rules [rule-name] | display set | nomore` - Show specific rule in set format

### IPv4 CGNAT Pool Configuration
```bash
set orgs org-services [org-name] cgnat pools [pool-name] routing-instance [vr-name]
set orgs org-services [org-name] cgnat pools [pool-name] egress-network [ network-name ]
set orgs org-services [org-name] cgnat pools [pool-name] source-port random-allocation
set orgs org-services [org-name] cgnat pools [pool-name] source-port allocation-scheme range-based
set orgs org-services [org-name] cgnat pools [pool-name] source-port range low [port]
set orgs org-services [org-name] cgnat pools [pool-name] source-port range high [port]
```

### IPv6 CGNAT Pool Configuration
```bash
set orgs org-services [org-name] cgnat pools [pool-name] referenced-outside-nat false
set orgs org-services [org-name] cgnat pools [pool-name] address [ ipv6-prefix ]
set orgs org-services [org-name] cgnat pools [pool-name] address-list [ ipv6-prefix ]
```

### IPv4 CGNAT Rule Configuration (NAPT44)
```bash
set orgs org-services [org-name] cgnat rules [rule-name] precedence [number]
set orgs org-services [org-name] cgnat rules [rule-name] paired-site true
set orgs org-services [org-name] cgnat rules [rule-name] from source-zone [ zone-name ]
set orgs org-services [org-name] cgnat rules [rule-name] from destination-zone [ zone-name ]
set orgs org-services [org-name] cgnat rules [rule-name] from routing-instance [vr-name]
set orgs org-services [org-name] cgnat rules [rule-name] from source-address [ ip-prefix ]
set orgs org-services [org-name] cgnat rules [rule-name] from source-address-list [ ip-prefix ]
set orgs org-services [org-name] cgnat rules [rule-name] then translated translation-type napt-44
set orgs org-services [org-name] cgnat rules [rule-name] then translated source-pool [pool-name]
set orgs org-services [org-name] cgnat rules [rule-name] then translated filtering-type endpoint-independent
set orgs org-services [org-name] cgnat rules [rule-name] then translated mapping-type endpoint-independent
```

### IPv6 CGNAT Rule Configuration (NPT66)
```bash
set orgs org-services [org-name] cgnat rules [rule-name] precedence [number]
set orgs org-services [org-name] cgnat rules [rule-name] paired-site false
set orgs org-services [org-name] cgnat rules [rule-name] from source-zone [ zone-name ]
set orgs org-services [org-name] cgnat rules [rule-name] from routing-instance [vr-name]
set orgs org-services [org-name] cgnat rules [rule-name] from source-address [ ipv6-prefix ]
set orgs org-services [org-name] cgnat rules [rule-name] from source-address-list [ ipv6-prefix ]
set orgs org-services [org-name] cgnat rules [rule-name] then translated translation-type npt-66
set orgs org-services [org-name] cgnat rules [rule-name] then translated source-pool [pool-name]
```

### CGNAT Configuration Examples

#### Create IPv6 CGNAT Pool and Rule
```bash
# Create IPv6 pool
admin@device-cli> configure
admin@device-cli(config)% set orgs org-services TEST-100 cgnat pools MPLS2_V6 referenced-outside-nat false
admin@device-cli(config)% set orgs org-services TEST-100 cgnat pools MPLS2_V6 address [ 2001:db8:2::/64 ]
admin@device-cli(config)% set orgs org-services TEST-100 cgnat pools MPLS2_V6 address-list [ 2001:db8:2::/64 ]

# Create IPv6 CGNAT rule
admin@device-cli(config)% set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA precedence 2
admin@device-cli(config)% set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA paired-site false
admin@device-cli(config)% set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA from source-zone [ MPLS-2-Failover ]
admin@device-cli(config)% set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA from routing-instance MPLS-2-Transport-VR
admin@device-cli(config)% set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA from source-address [ fc00::/64 ]
admin@device-cli(config)% set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA from source-address-list [ fc00::/64 ]
admin@device-cli(config)% set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA then translated translation-type npt-66
admin@device-cli(config)% set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA then translated source-pool MPLS2_V6
admin@device-cli(config)% commit
```

## Interface IPv6 Configuration

### Add IPv6 Address to Interface Unit
```bash
admin@device-cli> configure
admin@device-cli(config)% set interfaces [interface-name] unit [unit-number] family inet6 address [ipv6-address/prefix]
admin@device-cli(config)% commit
```

### Delete IPv6 Address from Interface Unit
```bash
admin@device-cli> configure
admin@device-cli(config)% delete interfaces [interface-name] unit [unit-number] family inet6 address [ipv6-address/prefix]
admin@device-cli(config)% commit
```

### Example: Configure Multiple Units with Same IPv6 Address
```bash
admin@device-cli> configure
# Add IPv6 to unit 1
admin@device-cli(config)% set interfaces vni-0/2 unit 1 family inet6 address fc00::2/64
# Update unit 5 (delete old, add new)
admin@device-cli(config)% delete interfaces vni-0/2 unit 5 family inet6 address 2001:db8:1::12/64
admin@device-cli(config)% set interfaces vni-0/2 unit 5 family inet6 address fc00::2/64
admin@device-cli(config)% commit
```

### Configure IPv6 Proxy-NDP for CGNAT
```bash
# CRITICAL: Proxy-NDP must be configured ONLY on egress (outbound NAT) WAN interface
# This advertises CGNAT pool IPv6 addresses to upstream provider/ISP
admin@device-cli> configure
admin@device-cli(config)% set interfaces [wan-interface] unit [unit] family inet6 proxy-ndp address [ ipv6-cgnat-pool ]
admin@device-cli(config)% commit

# Delete proxy-ndp if configured on wrong interface
admin@device-cli(config)% delete interfaces [interface] unit [unit] family inet6 proxy-ndp
admin@device-cli(config)% commit
```

### Example: Proxy-NDP for IPv6 CGNAT
```bash
# Configure on WAN egress interface (where NAT happens)
# vni-0/1 unit 0 = MPLS-2 WAN interface
# CGNAT pool = 2001:db8:2::/64
admin@device-cli> configure
admin@device-cli(config)% set interfaces vni-0/1 unit 0 family inet6 proxy-ndp address [ 2001:db8:2::/64 ]
admin@device-cli(config)% commit
```

## Routing Configuration

### Show Routing Table
```bash
# Show all routes in a VRF
admin@device-cli> show route routing-instance [vrf-name]

# Show specific protocol routes
admin@device-cli> show route routing-instance [vrf-name] protocol static

# Show specific route
admin@device-cli> show route routing-instance [vrf-name] [ip-address]
```

### IPv6 Static Route Configuration
```bash
# Configure IPv6 default route with ICMP monitoring
admin@device-cli> configure
admin@device-cli(config)% set routing-instances [vrf-name] routing-options static route ::/0 [next-hop-ipv6] none preference 1
admin@device-cli(config)% set routing-instances [vrf-name] routing-options static route ::/0 [next-hop-ipv6] none icmp
admin@device-cli(config)% set routing-instances [vrf-name] routing-options static route ::/0 [next-hop-ipv6] none icmp interval 5
admin@device-cli(config)% set routing-instances [vrf-name] routing-options static route ::/0 [next-hop-ipv6] none icmp threshold 6
admin@device-cli(config)% commit
```

### Example: IPv6 Default Route
```bash
# Add IPv6 default route to MPLS-2-Transport-VR
admin@device-cli> configure
admin@device-cli(config)% set routing-instances MPLS-2-Transport-VR routing-options static route ::/0 fc00::2 none preference 1
admin@device-cli(config)% set routing-instances MPLS-2-Transport-VR routing-options static route ::/0 fc00::2 none icmp
admin@device-cli(config)% set routing-instances MPLS-2-Transport-VR routing-options static route ::/0 fc00::2 none icmp interval 5
admin@device-cli(config)% set routing-instances MPLS-2-Transport-VR routing-options static route ::/0 fc00::2 none icmp threshold 6
admin@device-cli(config)% commit
```

## SD-WAN Monitoring

### SLA Monitor Status
```bash
# Show all SLA monitor paths
admin@device-cli> show orgs org [org-name] sd-wan sla-monitor status

# Show only IPv6 SLA paths
admin@device-cli> show orgs org [org-name] sd-wan sla-monitor status | tab | match v6

# Check specific path status
admin@device-cli> show orgs org [org-name] sd-wan sla-monitor status | match [path-name]
```

### Troubleshooting SLA Path Down
**Common causes for SLA path down:**
1. **Missing IPv6 routing** - No default route or next-hop unreachable
2. **Proxy-NDP not configured** - CGNAT pool not advertised to upstream
3. **Wrong interface** - Proxy-NDP on wrong interface (should be on egress WAN)
4. **Tunnel interface issues** - IPv6 not configured on tunnel interfaces

**Fix checklist:**
- Verify IPv6 default route exists: `show route routing-instance [vrf] ::/0`
- Verify proxy-ndp on egress WAN: `show configuration interfaces [wan-if] | display set | match proxy-ndp`
- Verify SLA path status: `show orgs org [org] sd-wan sla-monitor status | match [path]`

## Display Configuration Formats

### Show Configuration in Set Format
- `show configuration | display set` - Show entire config in set-based format
- `show configuration [path] | display set` - Show specific config path in set format
- `show configuration [path] | display set | nomore` - Show without pagination

### Example
```bash
# Show full config in set format
admin@device-cli> show configuration | display set | nomore

# Show specific interface in set format
admin@device-cli> show configuration interfaces vni-0/2 | display set | nomore

# Show CGNAT config in set format
admin@device-cli> show configuration orgs org-services TEST-100 cgnat | display set | nomore
```

## SD-LAN Commands and Troubleshooting

### SD-LAN Overview
SD-LAN with VXLAN consists of the following components:
- **Versa Headend**: Director, Analytics, Controller, and Concerto Orchestrator
- **Edge Gateway**: Versa SD-WAN network acting as Edge Gateway
- **Leaf Switches**: Access layer switches (VTEPs) that encapsulate/decapsulate VXLAN packets
- **Spine Switches**: Core layer switches interconnecting all leaf switches
- **Underlay Network**: Physical network using IP routing (OSPF/IS-IS)
- **Overlay Network**: Virtual network created by VXLAN

### EVPN Route Types
| Route Type | Name | Purpose | Description |
|------------|------|---------|-------------|
| Type 1 | Ethernet Auto-Discovery (A-D) Route | Discovering Ethernet segments | Advertises Ethernet segments and Tag IDs for multi-homing |
| Type 2 | MAC/IP Advertisement Route | Distributing MAC address reachability | Advertises MAC and IP addresses for Layer 2/3 reachability |
| Type 3 | Inclusive Multicast Ethernet Tag Route | Supporting multicast/broadcast traffic | Distributes multicast group and broadcast domain info |
| Type 4 | Ethernet Segment Route | Identifying Ethernet segments | Advertises ESI information for multi-homing |
| Type 5 | IP Prefix Route | Distributing IP prefix reachability | Advertises IP prefixes for Layer 3 VPN routes |

### Dot1x Authentication Commands
```bash
# Show Dot1x interfaces brief
admin@device-cli> show orgs org-services [org-name] access authentication-control dot1x interfaces brief

# Show Dot1x interfaces detail
admin@device-cli> show orgs org-services [org-name] access authentication-control dot1x interfaces detail
```

### LLDP Commands
```bash
# Show LLDP neighbors
admin@device-cli> show lldp neighbor brief
```

### IGP OSPF Commands
```bash
# Show OSPF database for Area 0
admin@device-cli> show ospf database area 0
```

### Bridge/MAC Learning Commands

#### Show MAC Address Table
```bash
# Display complete MAC address table
admin@device-cli> show bridge mac-table

# Display MAC table excluding empty entries
admin@device-cli> show bridge mac-table | except " 0 0 0 0 0"

# Display MAC table statistics (non-zero traffic only)
admin@device-cli> show bridge mac-table mac-stats | except " 0 0 0 0 0"

# Show MAC learning statistics for specific routing instance
admin@device-cli> show bridge mac-table mac-stats routing-instance [switch-name] | match "MAC address learned"

# Show brief MAC table
admin@device-cli> show bridge mac-table brief

# Show MAC table for specific bridge domain
admin@device-cli> show bridge mac-table brief routing-instance [switch-name] bridge-domain [bd-name]
```

#### MAC Type Legends
- **C**: Control - Controlled MAC entry
- **S**: Static - Statically configured MAC
- **D**: Dynamic - Dynamically learned MAC
- **R**: Router - Router interface MAC
- **V**: VRRP - VRRP MAC address
- **B**: Sink - Sink MAC entry
- **M**: Multi-Home - EVPN multi-homed MAC
- **A**: ARP - ARP learned MAC

### EVPN Route Table Commands

```bash
# Show EVPN routes for specific MAC address (received)
admin@device-cli> show route table l2vpn.evpn receive-protocol bgp mac-address [mac-address]

# Show EVPN routes for specific MAC address (advertised)
admin@device-cli> show route table l2vpn.evpn advertising-protocol bgp mac-address [mac-address]

# Show EVPN Type 1 routes (Ethernet Auto-Discovery)
admin@device-cli> show route table l2vpn.evpn receive-protocol bgp type 1

# Show EVPN Type 2 routes (MAC/IP Advertisement)
admin@device-cli> show route table l2vpn.evpn receive-protocol bgp type 2

# Show EVPN Type 3 routes (Inclusive Multicast)
admin@device-cli> show route table l2vpn.evpn receive-protocol bgp type 3

# Show EVPN Type 4 routes (Ethernet Segment)
admin@device-cli> show route table l2vpn.evpn receive-protocol bgp type 4

# Show EVPN Type 5 routes (IP Prefix Advertisement)
admin@device-cli> show route table l2vpn.evpn receive-protocol bgp type 5

# Show EVPN routes for specific VNI
admin@device-cli> show route table l2vpn.evpn receive-protocol bgp vni [vni-number]
```

### Bridge Table Commands

```bash
# Show ingress bridge table for specific routing instance
admin@device-cli> show bridge ingress-table routing-instance [switch-name] bridge-domain [bd-name]

# Show ARP suppression table
admin@device-cli> show bridge arp-suppression-table brief routing-instance [switch-name] bridge-domain [bd-name]
```

### Dynamic Tunnel Commands

```bash
# Show dynamic tunnel interfaces
admin@device-cli> show interfaces dynamic-tunnels
```

### Alarm Monitoring

```bash
# Show last N alarms
admin@device-cli> show alarms last-n [number]

# Example: Show last 100 alarms
admin@device-cli> show alarms last-n 100
```

### VSM SD-LAN Diagnostic Commands

Enter VSM shell first: `vsh connect vsmd`

```bash
# Show virtual network route summary
vsm> show vunet route summary

# Show VXLAN VNI table
vsm> show vsm vxlan-vni-table

# Show Layer 2 bridge domains
vsm> show vsm l2 bd

# Show bridge domain ARP table
vsm> show vsm l2 bd-arp-table [bd-id]

# Show STP table
vsm> show vsm l2 stp-table

# Show bridge domain MAC table
vsm> show vsm l2 bd-mac-table [bd-id]
```

### SD-LAN Staging Commands

```bash
# Onboard SD-WAN Edge device with static IP
sudo ./staging.py -l [login-org] -r [controller-org] -c [controller-ip] -s [static-ip/mask] -g [gateway] -w 0

# Onboard SD-LAN Switch with DHCP
sudo ./staging.py -l [login-org] -r [controller-org] -c [controller-ip] -d -w 0

# Example: SD-WAN Edge with static IP
sudo ./staging.py -l SDWAN-Branch@Provider-Org.com -r Controller-1-staging@Provider-Org.com -c 172.16.80.1 -s 172.16.82.72/24 -g 172.16.82.10 -w 0

# Example: SD-LAN Switch with DHCP
sudo ./staging.py -l SDWAN-Branch@Provider-Org.com -r Controller-1-staging@Provider-Org.com -c 172.16.80.1 -d -w 0
```

### L2 Interface Configuration

```bash
# Configure trunk interface with VLANs
configure
set interfaces [interface-name] unit [unit] vlan-members [vlan-list]
set interfaces [interface-name] unit [unit] native-vlan-id [vlan-id]
commit

# Configure access interface
configure
set interfaces [interface-name] unit [unit] vlan-members [vlan-id]
commit
```

### IRB (Integrated Routing and Bridging) Configuration

```bash
# Create IRB interface for VLAN
configure
set interfaces irb[number].[vlan-id] family inet address [ip-address/mask]
set interfaces irb[number].[vlan-id] family inet6 address [ipv6-address/prefix]
commit

# Associate IRB with routing instance
configure
set routing-instances [vrf-name] interface irb[number].[vlan-id]
commit

# Enable DHCP server on IRB
configure
set interfaces irb[number].[vlan-id] enable-dhcp true
commit
```

### Enable L2 Services in Organization

**IMPORTANT**: When using SD-WAN workflow templates with IRB/L2 configuration, you must manually enable L2 Services:

1. Navigate to: **Configuration > Organizations > [Org-Name] > Settings**
2. Under **Layer2** section, enable **Services** checkbox
3. Click **Update**

### Branch-in-a-Box Configuration

Branch-in-a-Box integrates SD-WAN, security, and switching capabilities on a single device:

**Features**:
- **VLAN Segmentation**: Users in different VLANs are isolated by default
- **IRB Inter-VLAN Routing**: IRB interfaces provide L3 gateway for VLAN-to-VLAN communication
- **Remote Site Access**: IRB-connected devices can reach remote SD-WAN sites and Internet

**Configuration Steps**:
1. Configure WAN interface(s)
2. Configure L2 access ports with VLAN assignments
3. Create IRB interfaces for each VLAN
4. Associate IRBs with VRF
5. Enable Split Tunneling
6. Enable L2 Services in Organization settings

### SD-LAN Onboarding Access Switch

**Workflow Template Configuration**:
- Device Type: **VM** (for CSX/Switch VM)
- Configure uplink port (vni-0/0) as **Trunk** with data VLANs + native VLAN
- Configure access ports in **Access** mode with VLAN assignment
- Switch Management Port: **Uplink port only** with native VLAN
- IPv4 Address: **DHCP** with Transport Domain assignment

**Device Template**:
- No bind data variables required for basic SD-LAN switch
- Deploy template and onboard using ZTP with `-d` (DHCP) option

### Verification Commands

```bash
# Verify uplink interface status on SD-LAN switch
admin@switch-cli> show interfaces brief vni-0/0
admin@switch-cli> show interfaces brief vni-0/0.[native-vlan]

# Verify MAC learning
admin@switch-cli> show bridge mac-table

# Verify VLAN connectivity from host
# Windows: ipconfig
# Linux: ip addr show

# Test inter-VLAN routing
ping [destination-vlan-gateway-ip]

# Verify internet connectivity
ping 8.8.8.8
```

## SD-LAN Troubleshooting Guide

### MAC Address Learning Issues

**Check local MAC table**:
```bash
show bridge mac-table brief routing-instance [switch-name] bridge-domain [bd-name]
```

**Check remote MAC learning via EVPN**:
```bash
show route table l2vpn.evpn receive-protocol bgp type 2
```

**Verify VNI configuration**:
```bash
vsh connect vsmd
show vsm vxlan-vni-table
```

### Connectivity Issues Between VLANs

1. **Verify IRB interfaces are UP**:
   ```bash
   show interfaces brief irb[number].[vlan-id]
   ```

2. **Check routing table for inter-VLAN routes**:
   ```bash
   show route routing-instance [vrf-name]
   ```

3. **Verify bridge domain configuration**:
   ```bash
   vsh connect vsmd
   show vsm l2 bd
   ```

4. **Check ARP suppression**:
   ```bash
   show bridge arp-suppression-table brief routing-instance [switch-name] bridge-domain [bd-name]
   ```

### SD-LAN Switch Not Coming Online

1. **Check uplink interface status**:
   ```bash
   show interfaces brief vni-0/0
   ```

2. **Verify DHCP on management VLAN**:
   ```bash
   show configuration interfaces vni-0/0.[native-vlan]
   ```

3. **Check controller connectivity**:
   ```bash
   ping [controller-ip]
   ```

4. **Verify staging parameters**:
   ```bash
   vsh show-staging-params
   ```

### EVPN Route Propagation Issues

1. **Check BGP EVPN session status**:
   ```bash
   show bgp summary
   ```

2. **Verify EVPN routes received**:
   ```bash
   show route table l2vpn.evpn receive-protocol bgp
   ```

3. **Check EVPN routes advertised**:
   ```bash
   show route table l2vpn.evpn advertising-protocol bgp
   ```

4. **Verify VSM tunnel statistics**:
   ```bash
   vsh connect vsmd
   show vsf tunnel stats
   ```

## Notes
- FlexVNF runs VOS (Versa Operating System)
- Two main modes: Shell (`$` prompt) and CLI (`>` prompt)
- Use `cli` command to enter CLI mode from shell
- Use `| nomore` to disable pagination for long outputs
- VSM (Versa Service Manager) shell provides advanced diagnostics
- **IPv6 CGNAT Translation Types:**
  - `npt-66` - IPv6-to-IPv6 Network Prefix Translation (correct)
  - `napt-66` - NOT SUPPORTED (will cause syntax error)
- **IPv4 CGNAT Translation Types:**
  - `napt-44` - IPv4-to-IPv4 Network Address Port Translation
- **Set-based commands:** Use `| display set` to show configuration in set format for easier copying/pasting
- **SD-LAN Deployment Models:**
  - **Branch-in-a-Box**: Single device with SD-WAN + switching capabilities
  - **Edge + Access Switch**: Separate SD-WAN edge with dedicated access switches
  - **Hub Deployment**: Central site with spine-leaf VXLAN fabric
- **MAC Learning**: VXLAN uses MP-BGP with L2VPN-EVPN NLRI for MAC address propagation across fabric
- **VNI (VXLAN Network Identifier)**: 24-bit identifier for VXLAN segments (similar to VLAN ID)
