locals {
  load_balancer_name = "${coalesce(var.vm_name, "${var.site_name}-vsocket")}-lb"
  ncc_hub_name       = var.ncc_hub_name != null ? var.ncc_hub_name : "${var.site_name}-ncc-hub"
  # Always include 0.0.0.0/0 so client internet goes only via security project (vSocket) for SASE.
  # GCP NCC rejects include_export_ranges when a subnet is provided together with 0.0.0.0/0.
  ncc_security_export_raw = distinct(concat(coalesce(var.ncc_security_spoke_export_ranges, [var.subnet_lan_cidr]), ["0.0.0.0/0"]))
  ncc_security_export     = contains(local.ncc_security_export_raw, "0.0.0.0/0") ? ["0.0.0.0/0"] : local.ncc_security_export_raw
  # Client-originated traffic source ranges: from variable or derived from ncc_client_spokes export_ranges
  ncc_client_source_ranges = length(var.ncc_client_traffic_source_ranges) > 0 ? var.ncc_client_traffic_source_ranges : flatten([for _, s in var.ncc_client_spokes : coalesce(s.export_ranges, [])])
  ncc_client_route_names = {
    for cidr in local.ncc_client_source_ranges :
    cidr => "${substr(local.ncc_hub_name, 0, 25)}-route-${substr(sha1("${local.ncc_hub_name}:${cidr}"), 0, 12)}"
  }

  # NCC STAR preset groups
  ncc_center_group_id = (
    var.ncc_spoke_isolation
    ? "center"
    : null
  )
  ncc_edge_group_id = (
    var.ncc_spoke_isolation
    ? "edge"
    : null
  )

  # Cloud Router + BGP
  # When BGP is enabled, auto-advertise client CIDRs via Cloud Router so vSocket
  # learns GCP client networks and can re-advertise them. Routes learned from
  # vSocket propagate through the Router Appliance spoke to the NCC hub and then
  # to client VPCs, providing the inspection transit path.
  auto_advertised_client_ranges = var.enable_cloud_router && var.enable_bgp && length(local.ncc_client_source_ranges) > 0 ? [
    for cidr in local.ncc_client_source_ranges : {
      range       = cidr
      description = "Client spoke CIDR (auto-added for BGP route injection)"
    }
  ] : []
  cloud_router_all_advertised_ranges = concat(
    var.cloud_router_advertised_ip_ranges,
    local.auto_advertised_client_ranges,
  )

  cloud_router_name                                 = var.cloud_router_name != null ? var.cloud_router_name : "${var.site_name}-lan-router"
  lan_subnet_self_link                              = "projects/${local.security_project_id}/regions/${var.region}/subnetworks/${module.vsocket_gcp_ha.subnet_lan_name}"
  enable_redundant_router_interface                 = var.enable_cloud_router && var.enable_bgp
  cloud_router_bgp_interface_ip_secondary_effective = coalesce(var.cloud_router_bgp_interface_ip_secondary, cidrhost(var.subnet_lan_cidr, 11))
  enable_secondary_bgp                              = var.ha && var.enable_cloud_router && var.enable_bgp && var.cloud_router_bgp_interface_ip_secondary != null

  primary_vm_self_link = (
    var.enable_bgp && var.primary_zone != null
    ? "projects/${local.security_project_id}/zones/${var.primary_zone}/instances/${module.vsocket_gcp_ha.primary_vm_instance_name}"
    : null
  )
  secondary_vm_self_link = (
    var.ha && local.enable_secondary_bgp && var.secondary_zone != null
    ? "projects/${local.security_project_id}/zones/${var.secondary_zone}/instances/${module.vsocket_gcp_ha.secondary_vm_instance_name}"
    : null
  )
  bgp_firewall_source_ranges = compact([
    var.cloud_router_bgp_interface_ip_primary != null ? "${var.cloud_router_bgp_interface_ip_primary}/32" : "",
    local.enable_redundant_router_interface ? "${local.cloud_router_bgp_interface_ip_secondary_effective}/32" : "",
  ])
}
