# Versa FlexVNF IPv6 CGNAT Configuration Session
**Date:** 2025-11-19
**Devices:** Spoke-1-HA1 (192.168.20.58), Spoke-1-HA2 (192.168.20.60)
**Objective:** Configure IPv6 CGNAT with NPT66 for MPLS-2 circuit

## Summary of Changes

### Spoke-1-HA2 (192.168.20.60) - Primary Configuration Device

#### 1. IPv6 Interface Configuration
**All vni-0/2 units configured with fc00::2/64:**
```bash
set interfaces vni-0/2 unit 1 family inet6 address fc00::2/64
set interfaces vni-0/2 unit 2 family inet6 address fc00::2/64  # Already existed
set interfaces vni-0/2 unit 4 family inet6 address fc00::2/64  # Already existed
delete interfaces vni-0/2 unit 5 family inet6 address 2001:db8:1::12/64
set interfaces vni-0/2 unit 5 family inet6 address fc00::2/64
```

#### 2. IPv6 CGNAT Pool
**Pool Name:** MPLS2_V6
**Network:** 2001:db8:2::/64 (from vni-0/1 unit 0)
```bash
set orgs org-services TEST-100 cgnat pools MPLS2_V6 referenced-outside-nat false
set orgs org-services TEST-100 cgnat pools MPLS2_V6 address [ 2001:db8:2::/64 ]
set orgs org-services TEST-100 cgnat pools MPLS2_V6 address-list [ 2001:db8:2::/64 ]
```

#### 3. IPv6 CGNAT Rule
**Rule Name:** IPV6_MPLS2_HA
**Translation Type:** npt-66 (IPv6-to-IPv6 Network Prefix Translation)
**Source:** fc00::/64 (MPLS-2-Failover zone)
**Destination Pool:** MPLS2_V6
```bash
set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA precedence 2
set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA paired-site false
set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA from source-zone [ MPLS-2-Failover ]
set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA from routing-instance MPLS-2-Transport-VR
set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA from source-address [ fc00::/64 ]
set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA from source-address-list [ fc00::/64 ]
set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA then translated translation-type npt-66
set orgs org-services TEST-100 cgnat rules IPV6_MPLS2_HA then translated source-pool MPLS2_V6
```

#### 4. IPv6 Proxy-NDP Configuration
**CRITICAL:** Configured ONLY on egress WAN interface (vni-0/1 unit 0)
**Purpose:** Advertise CGNAT pool to upstream MPLS provider
```bash
set interfaces vni-0/1 unit 0 family inet6 proxy-ndp address [ 2001:db8:2::/64 ]
```

**Note:** Initially misconfigured on vni-0/2 unit 2 (failover interface), but removed after troubleshooting.

### Spoke-1-HA1 (192.168.20.58) - IPv6 Routing Configuration

#### 5. IPv6 Static Default Route
**VRF:** MPLS-2-Transport-VR
**Next-hop:** fc00::2
**Monitoring:** ICMP health check enabled
```bash
set routing-instances MPLS-2-Transport-VR routing-options static route ::/0 fc00::2 none preference 1
set routing-instances MPLS-2-Transport-VR routing-options static route ::/0 fc00::2 none icmp
set routing-instances MPLS-2-Transport-VR routing-options static route ::/0 fc00::2 none icmp interval 5
set routing-instances MPLS-2-Transport-VR routing-options static route ::/0 fc00::2 none icmp threshold 6
```

## Troubleshooting & Resolution

### Issue: MPLS-2-v6 SLA Path Down
**Symptoms:**
```
MPLS-2-v6  MPLS-v6  10  9  -  disable  disable  0  down  1  15:48:35
```

**Root Cause:**
- Missing IPv6 Proxy-NDP on egress WAN interface
- CGNAT pool (2001:db8:2::/64) not advertised to upstream provider

**Resolution:**
1. Added IPv6 default route in MPLS-2-Transport-VR
2. Configured Proxy-NDP on vni-0/1 unit 0 (egress WAN interface)
3. Removed incorrect Proxy-NDP from vni-0/2 unit 2

**Result:**
```
MPLS-2-v6  MPLS-v6  10  9  -  disable  disable  0  up    2  00:00:32
```
✓ SLA paths UP
✓ IPv6 CGNAT operational

## Key Learnings

### IPv6 Proxy-NDP Best Practices
1. **Configure ONLY on egress (NAT outbound) WAN interface** - where packets exit after NAT
2. **NOT on failover interfaces** - unless they are also active egress paths
3. **Purpose:** Similar to IPv4 Proxy-ARP, advertises CGNAT pool addresses to upstream
4. **Effect:** Enables upstream provider to route traffic to CGNAT pool back to this device

### CGNAT Translation Types
- **IPv4:** `napt-44` - IPv4-to-IPv4 Network Address Port Translation
- **IPv6:** `npt-66` - IPv6-to-IPv6 Network Prefix Translation (stateless)
- **NOT SUPPORTED:** `napt-66` - causes syntax error

### Verification Commands
```bash
# Verify SLA path status
show orgs org TEST-100 sd-wan sla-monitor status | tab | match v6

# Verify IPv6 routing
show route routing-instance MPLS-2-Transport-VR protocol static

# Verify proxy-ndp configuration
show configuration interfaces vni-0/1 unit 0 | display set | match proxy-ndp

# Verify CGNAT configuration
show configuration orgs org-services TEST-100 cgnat | display set
```

## Files Modified/Created
1. `/mnt/c/Users/eniza/Documents/claudechats/versa-cli-commands.md` - Updated with new commands and examples
2. This session log: `versa-session-2025-11-19.md`

## Configuration Status
- ✅ IPv6 addressing on all vni-0/2 units
- ✅ IPv6 CGNAT pool (MPLS2_V6) created
- ✅ IPv6 CGNAT rule (IPV6_MPLS2_HA) configured
- ✅ IPv6 static route in MPLS-2-Transport-VR
- ✅ Proxy-NDP on egress WAN interface (vni-0/1.0)
- ✅ SLA paths operational (MPLS-2-v6 UP)
- ✅ Documentation updated

---
**Session End:** All configurations committed and verified operational.
