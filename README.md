# Cato vSocket GCP with NCC (Network Connectivity Center)

This Terraform module wraps the [Cato vSocket GCP HA module](https://github.com/catonetworks/terraform-cato-vsocket-gcp-ha) and adds **GCP Network Connectivity Center (NCC)** so that:

- The **security project** (where the vSocket runs) and **client projects** are connected via an NCC hub.
- Client projects can communicate with each other and with the vSocket through the hub.
- When **Cloud Router + BGP** is enabled, the vSocket can inject routes into the NCC hub. Routes advertised by vSocket via BGP propagate through the Router Appliance spoke to all client VPCs, steering traffic through the security VPC for **SASE inspection**.

## Requirements

- The same requirements as the [vSocket GCP HA module](https://github.com/catonetworks/terraform-cato-vsocket-gcp-ha).
- **Network Connectivity API** enabled in the security project and in every client project.
- Terraform identity with **`roles/networkconnectivity.spokeAdmin`** in the security project and in each client project (to create spokes).

## Module source

By default this module calls the vSocket HA module from a local path:

- **`vsocket_module_source`** (default: `"../terraform-cato-vsocket-gcp-ha"`) — Use this when the two repos are side by side. Override with a registry source (e.g. `"catonetworks/vsocket-gcp-ha/cato"`) or another path as needed.

## Usage

Use this module instead of the vSocket HA module when you want NCC and SASE (client internet only via vSocket). Pass the same variables you would to the vSocket HA module, plus NCC-specific ones.

By default, deployments are **HA** (`ha = true`). To deploy a **non-HA** single vSocket, set `ha = false` and omit secondary IP/zone inputs.

### Example (aligned with `vsocket-ha-ncc-router-bgp`)

```hcl
module "vsocket_gcp_ha_ncc" {
  source = "../../../../../terraform-cato-vsocket-gcp-ha-ncc-mesh"

  vsocket_module_source = "../terraform-cato-vsocket-gcp-ha"  # optional; this is the default

  token      = var.token
  account_id = var.account_id
  baseurl    = var.baseurl

  site_name        = "security-bgp"
  site_description = "Security project vSocket with NCC + Cloud Router + BGP"
  region           = "europe-west1"
  primary_zone     = "europe-west1-b"
  ha               = false

  subnet_mgmt_cidr = "10.3.1.0/24"
  subnet_wan_cidr  = "10.4.2.8/29"
  subnet_lan_cidr  = "10.4.3.0/24"

  mgmt_network_ip_primary = "10.4.1.4"
  wan_network_ip_primary  = "10.4.2.10"
  lan_network_ip_primary  = "10.4.3.4"
  # secondary_* and load_balancer_ip are optional in non-HA

  # NCC: STAR topology forces spoke-to-spoke through center/vSocket path
  ncc_spoke_isolation = true
  ncc_client_spokes = {
    "web-tier" = {
      project_id      = "web-test-484208"
      vpc_network_uri = "https://www.googleapis.com/compute/v1/projects/web-test-484208/global/networks/web-vpc-1"
      export_ranges   = ["10.1.0.0/16"]
    }
    "app-tier" = {
      project_id      = "app-test-484208"
      vpc_network_uri = "https://www.googleapis.com/compute/v1/projects/app-test-484208/global/networks/app-vpc-1"
      export_ranges   = ["10.2.0.0/16"]
    }
  }

  # Cloud Router + BGP
  enable_cloud_router                   = true
  enable_bgp                            = true
  cloud_router_asn                      = 64520
  cato_bgp_asn                          = 64515
  cloud_router_bgp_interface_ip_primary = "10.4.3.10"

  # Cato-side BGP advertisements (required for inspected inter-spoke path)
  cato_bgp_peer_advertise_default_route = true
  cato_bgp_peer_summary_routes = [
    { route = "10.1.0.0/16" },
    { route = "10.2.0.0/16" },
  ]

  # Make summary routes eligible for advertisement on Cato side
  routed_networks = {
    web-tier = {
      subnet          = "10.1.0.0/16"
      interface_index = "LAN1"
      gateway         = "10.4.3.1"
    }
    app-tier = {
      subnet          = "10.2.0.0/16"
      interface_index = "LAN1"
      gateway         = "10.4.3.1"
    }
  }
}
```

Enable the APIs:

```bash
gcloud services enable networkconnectivity.googleapis.com --project=SECURITY_PROJECT_ID
gcloud services enable networkconnectivity.googleapis.com --project=CLIENT_PROJECT_ID
```

**Spoke approval:** When a spoke is in a different project than the hub, the hub administrator must accept the spoke (Console or gcloud), or use a hub group with auto-accept for the client project IDs.

## Traffic inspection via Cloud Router + BGP (recommended)

The recommended architecture for **inspecting inter-spoke and internet traffic** in the vSocket uses the NCC **Router Appliance** pattern with Cloud Router and BGP:

1. A **Cloud Router** is created in the security LAN VPC.
2. The vSocket VM(s) are registered as **Router Appliance** instances via a regional NCC spoke.
3. Cloud Router establishes **BGP sessions** with the vSocket(s).
4. Client CIDRs (from `ncc_client_spokes` export ranges) are **automatically advertised** by Cloud Router to vSocket, so vSocket knows about GCP client networks.
5. On the **Cato side**, vSocket is configured to advertise routes back to Cloud Router (e.g. `0.0.0.0/0`).
6. These BGP-learned routes propagate through the **Router Appliance spoke** into the NCC hub and on to all client VPCs.

### How traffic is inspected (web → app)

1. Web VM sends a packet to app IP (e.g. `10.2.x.x`).
2. In the web VPC, the BGP-learned route (from Router Appliance spoke) steers the packet to the security LAN VPC.
3. A **policy-based route** in the security LAN VPC matches the client source CIDR and forwards to the **Internal Load Balancer → vSocket**.
4. vSocket **inspects** the traffic (SASE policy).
5. vSocket forwards the packet. The security LAN VPC routes it to the app VPC via NCC (subnet routes from the app spoke).

### Network flow summary

| Scenario | Path |
|----------|------|
| **VM → Internet** | Client VPC → (BGP default route via Router Appliance) → Security LAN VPC → PBR → ILB → vSocket → Internet. **Inspected.** |
| **VM → Another client project** | Client A VPC → (BGP route via Router Appliance) → Security LAN VPC → PBR → ILB → vSocket → NCC → Client B VPC. **Inspected.** |
| **VM → Same VPC subnet** | Normal VPC internal routing; NCC and vSocket not used. |
| **On-prem → GCP VM** | On-prem → Cato SDWAN → vSocket → LAN VPC → NCC → Client VPC → VM |
| **GCP VM → On-prem** | VM → Client VPC → NCC → LAN VPC → (dynamic route) → vSocket → Cato SDWAN → On-prem |

### Cato-side BGP configuration (automatic)

When `create_cato_bgp_peer = true` (default), the module automatically creates [`cato_bgp_peer`](https://github.com/catonetworks/terraform-provider-cato/blob/main/docs/resources/bgp_peer.md) resources via the Cato API. This configures the vSocket to:

- Peer with the Cloud Router using the correct ASN and interface IPs.
- **Advertise `0.0.0.0/0`** (default route) by default (`cato_bgp_peer_advertise_default_route = true`), capturing both inter-spoke and internet traffic. The BGP-learned default route injected via Router Appliance overrides the VPC's built-in default gateway route (priority 1000) because NCC-propagated routes have a lower priority value.
- Optionally advertise **summary routes** (e.g. specific client CIDRs) via `cato_bgp_peer_summary_routes`.

Set `create_cato_bgp_peer = false` to skip automatic Cato configuration and manage BGP peers manually in the Cato Management Application.

Without vSocket BGP advertisements (automatic or manual), no routes propagate from the Router Appliance spoke and client VPCs have no transit path through the security VPC.

### Example with Cloud Router + BGP (non-HA, recommended for this example)

```hcl
module "vsocket_gcp_ha_ncc" {
  source = "../../../../../terraform-cato-vsocket-gcp-ha-ncc-mesh"

  # ... base + NCC configuration ...

  primary_zone = "europe-west1-b"
  ha           = false

  # Cloud Router (GCP side)
  enable_cloud_router = true
  cloud_router_asn    = 64520

  # BGP peering with vSocket (GCP side)
  enable_bgp                            = true
  cato_bgp_asn                          = 64515
  cloud_router_bgp_interface_ip_primary = "10.4.3.10"

  # BGP tuning
  advertised_route_priority = 100
  enable_bfd                = true

  # Cato-side BGP peer (auto-configured via Cato API) — explicit summaries
  create_cato_bgp_peer                  = true
  cato_bgp_peer_advertise_default_route = true
  cato_bgp_peer_summary_routes = [
    { route = "10.1.0.0/16" },
    { route = "10.2.0.0/16" },
  ]

  routed_networks = {
    web-tier = {
      subnet          = "10.1.0.0/16"
      interface_index = "LAN1"
      gateway         = "10.4.3.1"
    }
    app-tier = {
      subnet          = "10.2.0.0/16"
      interface_index = "LAN1"
      gateway         = "10.4.3.1"
    }
  }
}
```

### Example with non-HA vSocket

```hcl
module "vsocket_gcp_ha_ncc" {
  source = "../terraform-cato-vsocket-gcp-ha-ncc"

  # ... base + NCC configuration ...
  ha           = false
  primary_zone = "us-central1-a"

  # only primary vSocket IPs are required
  mgmt_network_ip_primary = "10.3.1.4"
  wan_network_ip_primary  = "10.3.2.4"
  lan_network_ip_primary  = "10.3.3.4"

  # optional BGP (single peer)
  enable_cloud_router                    = true
  enable_bgp                             = true
  cloud_router_bgp_interface_ip_primary  = "10.3.3.10"
  cloud_router_bgp_interface_ip_secondary = null
}
```

### NCC route priority and prefix length

When Cloud Router + BGP is enabled with MESH topology (default), be aware of NCC route selection:

- **VPC spoke** subnet routes are preferred over **Router Appliance** routes for the **same prefix length**.
- To ensure BGP-injected routes win for inter-spoke traffic, vSocket should advertise prefixes that are **more specific** than VPC spoke subnet routes, or use `0.0.0.0/0` as a catch-all.
- For internet traffic, a BGP-learned `0.0.0.0/0` always wins over the VPC default gateway (priority 1000).

### Optional: STAR topology (`ncc_spoke_isolation`)

Setting `ncc_spoke_isolation = true` switches the hub to **STAR** preset topology:

- Security + Router Appliance spokes → **center** group.
- Client spokes → **edge** group.
- Edges only see center routes — direct edge-to-edge route exchange is blocked.
- BGP-learned routes from the center (Router Appliance) are the **only** routes edges receive.

This eliminates the NCC route priority concern (no competing VPC spoke routes between edges), but requires `enable_cloud_router + enable_bgp` and Cato-side BGP configuration. **Changing topology on an existing hub forces hub recreation.**

## NCC-specific variables

| Name | Description | Default |
|------|-------------|---------|
| `ncc_hub_name` | Name of the NCC hub. | `"{site_name}-ncc-hub"` |
| `ncc_spoke_isolation` | Switch hub to STAR preset topology (center/edge groups). | `false` |
| `ncc_security_spoke_export_ranges` | CIDR ranges to export from the security LAN VPC; 0.0.0.0/0 is always added for SASE. | `[subnet_lan_cidr]` |
| `ncc_client_traffic_source_ranges` | CIDRs for client-originated traffic (policy-based routes to vSocket). If empty, derived from `ncc_client_spokes` `export_ranges`. | `[]` |
| `ncc_client_spokes` | Map of client spokes: `project_id`, `vpc_network_uri`, optional `export_ranges`. | `{}` |

## Cloud Router + BGP variables

| Name | Description | Default |
|------|-------------|---------|
| `enable_cloud_router` | Create a Cloud Router in the LAN VPC. | `false` |
| `ha` | Deploy in HA mode (`true`) or non-HA single vSocket (`false`). | `true` |
| `cloud_router_name` | Name of the Cloud Router. | `"{site_name}-lan-router"` |
| `cloud_router_asn` | Cloud Router BGP ASN. | `64520` |
| `cloud_router_advertised_ip_ranges` | IP ranges to advertise to BGP peers (list of `{range, description}`). | `[]` |
| `enable_bgp` | Enable BGP peering with vSocket via Router Appliance. Requires `enable_cloud_router`. | `false` |
| `cato_bgp_asn` | Cato vSocket BGP ASN. | `64515` |
| `cloud_router_bgp_interface_ip_primary` | Cloud Router primary BGP interface IP (in LAN subnet). | — |
| `cloud_router_bgp_interface_ip_secondary` | Cloud Router secondary BGP interface IP (HA). | `null` |
| `advertised_route_priority` | BGP route priority (lower = preferred). Secondary uses +100. | `100` |
| `enable_bfd` | Enable BFD for faster failure detection. | `true` |
| `bfd_min_transmit_interval` | BFD min transmit interval (ms). | `1000` |
| `bfd_min_receive_interval` | BFD min receive interval (ms). | `1000` |
| `bfd_multiplier` | BFD detection multiplier (5–16). | `5` |
| `create_bgp_firewall_rule` | Create firewall rules for BGP/BFD traffic. | `true` |

## Cato BGP peer variables

| Name | Description | Default |
|------|-------------|---------|
| `create_cato_bgp_peer` | Create `cato_bgp_peer` resources for automatic Cato-side BGP configuration. Requires `enable_bgp`. | `true` |
| `cato_bgp_peer_default_action` | Default action for routes not matching filters (ACCEPT or DROP). | `"ACCEPT"` |
| `cato_bgp_peer_advertise_default_route` | Advertise `0.0.0.0/0` from vSocket to Cloud Router. | `true` |
| `cato_bgp_peer_advertise_all_routes` | Advertise all Cato routes to the Cloud Router. | `false` |
| `cato_bgp_peer_summary_routes` | Summary routes to advertise (list of `{route, community}`). | `[]` |
| `cato_bgp_peer_metric` | Route preference metric (lower = preferred). | `150` |

All other variables are passed through to the vSocket GCP HA module; see that module's documentation for details.

## Outputs

All outputs from the vSocket GCP HA module are re-exported. In addition:

- **`ncc_hub_id`** — NCC hub ID (for reference or additional spokes).
- **`ncc_hub_name`** — NCC hub name.
- **`ncc_security_spoke_id`** — Security project VPC spoke ID.
- **`ncc_client_spoke_ids`** — Map of client spoke name → spoke ID.
- **`ncc_hub_topology`** — Hub topology (`STAR` or `MESH`).
- **`ncc_client_group_ids`** — Map of client spoke name → effective hub group ID (`edge` in STAR, `null` in MESH).
- **`cloud_router_id`** — Cloud Router ID (when enabled).
- **`cloud_router_name`** — Cloud Router name (when enabled).
- **`router_appliance_spoke_id`** — Router Appliance NCC spoke ID (when BGP enabled).
- **`bgp_peer_status_command`** — `gcloud` command to check BGP session status.
- **`cato_bgp_peer_primary_id`** — Cato BGP peer ID (primary).
- **`cato_bgp_peer_secondary_id`** — Cato BGP peer ID (secondary/HA).

## License

Apache 2 Licensed.
