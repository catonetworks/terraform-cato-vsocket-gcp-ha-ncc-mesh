# ------------------------------------------------------------------------------
# Cato vSocket GCP HA (base module)
# ------------------------------------------------------------------------------
module "vsocket_gcp_ha" {
  #source = "catonetworks/vsocket-gcp-ha/cato"
  source = "../terraform-cato-vsocket-gcp-ha"

  token      = var.token
  account_id = var.account_id
  baseurl    = var.baseurl

  site_name        = var.site_name
  site_description = var.site_description
  site_location    = var.site_location
  site_type        = var.site_type

  region         = var.region
  primary_zone   = var.primary_zone
  secondary_zone = var.secondary_zone
  ha             = var.ha

  vpc_mgmt_name = var.vpc_mgmt_name
  vpc_wan_name  = var.vpc_wan_name
  vpc_lan_name  = var.vpc_lan_name

  subnet_mgmt_name = var.subnet_mgmt_name
  subnet_wan_name  = var.subnet_wan_name
  subnet_lan_name  = var.subnet_lan_name

  subnet_mgmt_cidr = var.subnet_mgmt_cidr
  subnet_wan_cidr  = var.subnet_wan_cidr
  subnet_lan_cidr  = var.subnet_lan_cidr

  ip_mgmt_name = var.ip_mgmt_name
  ip_wan_name  = var.ip_wan_name

  boot_disk_size  = var.boot_disk_size
  boot_disk_image = var.boot_disk_image
  machine_type    = var.machine_type
  vm_name         = var.vm_name

  network_tier = var.network_tier

  mgmt_network_ip_primary   = var.mgmt_network_ip_primary
  mgmt_network_ip_secondary = var.mgmt_network_ip_secondary
  wan_network_ip_primary    = var.wan_network_ip_primary
  wan_network_ip_secondary  = var.wan_network_ip_secondary
  lan_network_ip_primary    = var.lan_network_ip_primary
  lan_network_ip_secondary  = var.lan_network_ip_secondary
  load_balancer_ip          = var.load_balancer_ip

  public_ip_mgmt = var.public_ip_mgmt
  public_ip_wan  = var.public_ip_wan

  lan_firewall_rule_name = var.lan_firewall_rule_name
  create_firewall_rule   = var.create_firewall_rule

  labels = var.labels
  tags   = var.tags

  license_id                      = var.license_id
  license_bw                      = var.license_bw
  routed_networks                 = var.routed_networks
  enable_static_range_translation = var.enable_static_range_translation

  upstream_bandwidth   = var.upstream_bandwidth
  downstream_bandwidth = var.downstream_bandwidth
}

data "google_client_config" "current" {}

locals {
  security_project_id = data.google_client_config.current.project
  vpc_lan_id          = "projects/${local.security_project_id}/global/networks/${module.vsocket_gcp_ha.vpc_lan_name}"
  vpc_lan_self_link   = "https://www.googleapis.com/compute/v1/${local.vpc_lan_id}"
}

# ------------------------------------------------------------------------------
# GCP Network Connectivity Center (NCC) Hub
# ------------------------------------------------------------------------------
# Creates an NCC hub in the security project, attaches the LAN VPC as a spoke,
# and creates VPC spokes for each entry in ncc_client_spokes. Client project
# internet traffic is allowed only via the security project (vSocket) for SASE.
# ------------------------------------------------------------------------------

resource "google_network_connectivity_hub" "ncc_hub" {
  name            = local.ncc_hub_name
  description     = "NCC hub for security project (vSocket) and client projects. Connects LAN VPC to client VPCs."
  labels          = var.labels
  preset_topology = var.ncc_spoke_isolation ? "STAR" : null
}

resource "google_network_connectivity_spoke" "ncc_security_spoke" {
  name     = "${var.site_name}-security-spoke"
  location = "global"
  hub      = google_network_connectivity_hub.ncc_hub.id
  group    = local.ncc_center_group_id
  labels   = var.labels

  linked_vpc_network {
    uri                   = local.vpc_lan_self_link
    include_export_ranges = local.ncc_security_export
  }
}

resource "google_network_connectivity_spoke" "ncc_client_spoke" {
  for_each = var.ncc_client_spokes
  name     = "${var.site_name}-${each.key}-spoke"
  location = "global"
  project  = each.value.project_id
  hub      = google_network_connectivity_hub.ncc_hub.id
  group    = local.ncc_edge_group_id
  labels   = var.labels

  linked_vpc_network {
    uri                   = each.value.vpc_network_uri
    include_export_ranges = coalesce(each.value.export_ranges, [])
  }
}

# Policy-based routes so client-originated traffic (arriving via NCC) is sent to the vSocket
resource "google_network_connectivity_policy_based_route" "route_client_to_socket" {
  for_each = toset(local.ncc_client_source_ranges)
  name     = "${local.load_balancer_name}-route-client-to-socket-${replace(replace(each.value, ".", "-"), "/", "-")}"
  network  = local.vpc_lan_id
  priority = 1000

  filter {
    protocol_version = "IPV4"
    src_range        = each.value
    dest_range       = "0.0.0.0/0"
  }

  next_hop_ilb_ip = module.vsocket_gcp_ha.load_balancer_ip
}

# ------------------------------------------------------------------------------
# GCP Cloud Router + BGP (optional)
# ------------------------------------------------------------------------------
# Creates a Cloud Router in the LAN VPC and registers the vSocket VM(s) as NCC
# Router Appliance instances. Cloud Router establishes BGP sessions with the
# vSocket(s). Client CIDRs are auto-advertised to vSocket so it knows about GCP
# networks. When create_cato_bgp_peer is true, the Cato-side BGP peers are also
# provisioned automatically via the Cato API. Routes that vSocket advertises
# propagate through the Router Appliance spoke into the NCC hub and on to client
# VPCs, providing the inspection transit path (all traffic via vSocket).
# ------------------------------------------------------------------------------

resource "google_compute_router" "lan_router" {
  count = var.enable_cloud_router ? 1 : 0

  name    = local.cloud_router_name
  network = local.vpc_lan_id
  region  = var.region
  project = local.security_project_id

  bgp {
    asn               = var.cloud_router_asn
    advertise_mode    = length(local.cloud_router_all_advertised_ranges) > 0 ? "CUSTOM" : "DEFAULT"
    advertised_groups = length(local.cloud_router_all_advertised_ranges) > 0 ? ["ALL_SUBNETS"] : null

    dynamic "advertised_ip_ranges" {
      for_each = local.cloud_router_all_advertised_ranges
      content {
        range       = advertised_ip_ranges.value.range
        description = advertised_ip_ranges.value.description
      }
    }
  }
}

# Router Appliance spoke — registers vSocket VM(s) so Cloud Router can peer
# with them via BGP. This is the GCP-supported mechanism for Cloud Router to
# establish BGP sessions with VM instances (direct VM IP peering is not possible).
resource "google_network_connectivity_spoke" "router_appliance" {
  count = var.enable_cloud_router && var.enable_bgp ? 1 : 0

  name     = "${var.site_name}-router-appliance-spoke"
  location = var.region
  hub      = google_network_connectivity_hub.ncc_hub.id
  group    = local.ncc_center_group_id
  project  = local.security_project_id
  labels   = var.labels

  linked_router_appliance_instances {
    instances {
      virtual_machine = local.primary_vm_self_link
      ip_address      = var.lan_network_ip_primary
    }

    dynamic "instances" {
      for_each = local.enable_secondary_bgp ? [1] : []
      content {
        virtual_machine = local.secondary_vm_self_link
        ip_address      = var.lan_network_ip_secondary
      }
    }

    site_to_site_data_transfer = true
  }

  lifecycle {
    precondition {
      condition     = var.primary_zone != null
      error_message = "primary_zone must be set when enable_bgp is true (needed to reference vSocket VM)."
    }
    precondition {
      condition     = var.cloud_router_bgp_interface_ip_primary != null
      error_message = "cloud_router_bgp_interface_ip_primary must be set when enable_bgp is true."
    }
    precondition {
      condition     = !local.enable_secondary_bgp || var.secondary_zone != null
      error_message = "secondary_zone must be set when cloud_router_bgp_interface_ip_secondary is provided."
    }
  }
}

# --- Primary BGP session (Cloud Router ↔ primary vSocket) ---

resource "google_compute_router_interface" "primary" {
  count = var.enable_cloud_router && var.enable_bgp ? 1 : 0

  name                = "${local.cloud_router_name}-primary"
  router              = google_compute_router.lan_router[0].name
  region              = var.region
  project             = local.security_project_id
  subnetwork          = local.lan_subnet_self_link
  private_ip_address  = var.cloud_router_bgp_interface_ip_primary
  redundant_interface = local.enable_redundant_router_interface ? google_compute_router_interface.secondary[0].name : null

  depends_on = [google_network_connectivity_spoke.router_appliance]
}

resource "google_compute_router_peer" "primary" {
  count = var.enable_cloud_router && var.enable_bgp ? 1 : 0

  name                      = "${local.cloud_router_name}-primary"
  router                    = google_compute_router.lan_router[0].name
  region                    = var.region
  project                   = local.security_project_id
  interface                 = google_compute_router_interface.primary[0].name
  router_appliance_instance = local.primary_vm_self_link
  peer_ip_address           = var.lan_network_ip_primary
  peer_asn                  = var.cato_bgp_asn
  advertised_route_priority = var.advertised_route_priority

  dynamic "bfd" {
    for_each = var.enable_bfd ? [1] : []
    content {
      session_initialization_mode = "ACTIVE"
      min_transmit_interval       = var.bfd_min_transmit_interval
      min_receive_interval        = var.bfd_min_receive_interval
      multiplier                  = var.bfd_multiplier
    }
  }

  # When HA BGP is enabled, primary peer must be created only after the
  # secondary (redundant) interface exists, otherwise GCP rejects it.
  depends_on = [
    google_network_connectivity_spoke.router_appliance,
    google_compute_router_interface.secondary,
  ]
}

# --- Secondary BGP session (Cloud Router ↔ secondary vSocket, HA) ---

resource "google_compute_router_interface" "secondary" {
  count = local.enable_redundant_router_interface ? 1 : 0

  name               = "${local.cloud_router_name}-secondary"
  router             = google_compute_router.lan_router[0].name
  region             = var.region
  project            = local.security_project_id
  subnetwork         = local.lan_subnet_self_link
  private_ip_address = local.cloud_router_bgp_interface_ip_secondary_effective

  depends_on = [google_network_connectivity_spoke.router_appliance]
}

resource "google_compute_router_peer" "secondary" {
  count = local.enable_secondary_bgp ? 1 : 0

  name                      = "${local.cloud_router_name}-secondary"
  router                    = google_compute_router.lan_router[0].name
  region                    = var.region
  project                   = local.security_project_id
  interface                 = google_compute_router_interface.secondary[0].name
  router_appliance_instance = local.secondary_vm_self_link
  peer_ip_address           = var.lan_network_ip_secondary
  peer_asn                  = var.cato_bgp_asn
  advertised_route_priority = var.advertised_route_priority + 100

  dynamic "bfd" {
    for_each = var.enable_bfd ? [1] : []
    content {
      session_initialization_mode = "ACTIVE"
      min_transmit_interval       = var.bfd_min_transmit_interval
      min_receive_interval        = var.bfd_min_receive_interval
      multiplier                  = var.bfd_multiplier
    }
  }

  depends_on = [google_network_connectivity_spoke.router_appliance]
}

# --- Firewall rule for BGP + BFD traffic ---

resource "google_compute_firewall" "allow_bgp" {
  count = var.enable_cloud_router && var.enable_bgp && var.create_bgp_firewall_rule ? 1 : 0

  name    = "${var.site_name}-allow-bgp"
  network = local.vpc_lan_id
  project = local.security_project_id

  allow {
    protocol = "tcp"
    ports    = ["179"]
  }

  dynamic "allow" {
    for_each = var.enable_bfd ? [1] : []
    content {
      protocol = "udp"
      ports    = ["3784", "3785"]
    }
  }

  source_ranges = local.bgp_firewall_source_ranges
}

# ------------------------------------------------------------------------------
# Cato BGP peers (vSocket-side configuration via Cato API)
# ------------------------------------------------------------------------------
# Creates BGP peer entries on the Cato site so the vSocket automatically peers
# with the Cloud Router and advertises routes (e.g. 0.0.0.0/0) back into GCP.
# These routes propagate via the Router Appliance spoke into the NCC hub and
# on to client VPCs, completing the inspection transit path.
# ------------------------------------------------------------------------------

resource "cato_bgp_peer" "primary" {
  count = var.enable_cloud_router && var.enable_bgp && var.create_cato_bgp_peer ? 1 : 0

  site_id        = module.vsocket_gcp_ha.site_id
  name           = "${local.cloud_router_name}-primary"
  cato_asn       = var.cato_bgp_asn
  peer_asn       = var.cloud_router_asn
  peer_ip        = var.cloud_router_bgp_interface_ip_primary
  metric         = var.cato_bgp_peer_metric
  default_action = var.cato_bgp_peer_default_action

  advertise_default_route  = var.cato_bgp_peer_advertise_default_route
  advertise_all_routes     = var.cato_bgp_peer_advertise_all_routes
  advertise_summary_routes = length(var.cato_bgp_peer_summary_routes) > 0
  summary_route            = var.cato_bgp_peer_summary_routes

  bfd_enabled = var.enable_cato_bfd
  bfd_settings = var.enable_cato_bfd ? {
    transmit_interval = var.bfd_min_transmit_interval
    receive_interval  = var.bfd_min_receive_interval
    multiplier        = var.bfd_multiplier
  } : null

  depends_on = [google_compute_router_peer.primary]
}

resource "cato_bgp_peer" "secondary" {
  count = local.enable_secondary_bgp && var.create_cato_bgp_peer ? 1 : 0

  site_id        = module.vsocket_gcp_ha.site_id
  name           = "${local.cloud_router_name}-secondary"
  cato_asn       = var.cato_bgp_asn
  peer_asn       = var.cloud_router_asn
  peer_ip        = var.cloud_router_bgp_interface_ip_secondary
  metric         = var.cato_bgp_peer_metric
  default_action = var.cato_bgp_peer_default_action

  advertise_default_route  = var.cato_bgp_peer_advertise_default_route
  advertise_all_routes     = var.cato_bgp_peer_advertise_all_routes
  advertise_summary_routes = length(var.cato_bgp_peer_summary_routes) > 0
  summary_route            = var.cato_bgp_peer_summary_routes

  bfd_enabled = var.enable_cato_bfd
  bfd_settings = var.enable_cato_bfd ? {
    transmit_interval = var.bfd_min_transmit_interval
    receive_interval  = var.bfd_min_receive_interval
    multiplier        = var.bfd_multiplier
  } : null

  depends_on = [google_compute_router_peer.secondary]
}
