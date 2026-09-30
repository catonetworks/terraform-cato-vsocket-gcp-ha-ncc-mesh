# ------------------------------------------------------------------------------
# Pass-through outputs from the vSocket GCP HA module
# ------------------------------------------------------------------------------
output "site_id" {
  description = "ID of the created Cato site"
  value       = module.vsocket_gcp_ha.site_id
}
output "site_name" {
  description = "Name of the created Cato site"
  value       = module.vsocket_gcp_ha.site_name
}
output "primary_boot_disk_name" {
  description = "Boot disk name for the primary vSocket VM"
  value       = module.vsocket_gcp_ha.primary_boot_disk_name
}
output "primary_boot_disk_self_link" {
  description = "Self-link for the primary vSocket boot disk"
  value       = module.vsocket_gcp_ha.primary_boot_disk_self_link
}
output "primary_vm_instance_name" {
  description = "Name of the primary vSocket VM instance"
  value       = module.vsocket_gcp_ha.primary_vm_instance_name
}
output "primary_vm_mgmt_network_ip" {
  description = "Management network private IP of the primary vSocket VM"
  value       = module.vsocket_gcp_ha.primary_vm_mgmt_network_ip
}
output "primary_vm_wan_network_ip" {
  description = "WAN network private IP of the primary vSocket VM"
  value       = module.vsocket_gcp_ha.primary_vm_wan_network_ip
}
output "primary_vm_lan_network_ip" {
  description = "LAN network private IP of the primary vSocket VM"
  value       = module.vsocket_gcp_ha.primary_vm_lan_network_ip
}
output "primary_vm_mgmt_public_ip" {
  description = "Management public IP of the primary vSocket VM if assigned"
  value       = module.vsocket_gcp_ha.primary_vm_mgmt_public_ip
}
output "primary_vm_wan_public_ip" {
  description = "WAN public IP of the primary vSocket VM if assigned"
  value       = module.vsocket_gcp_ha.primary_vm_wan_public_ip
}
output "secondary_boot_disk_name" {
  description = "Boot disk name for the secondary vSocket VM"
  value       = var.ha ? module.vsocket_gcp_ha.secondary_boot_disk_name : null
}
output "secondary_boot_disk_self_link" {
  description = "Self-link for the secondary vSocket boot disk"
  value       = var.ha ? module.vsocket_gcp_ha.secondary_boot_disk_self_link : null
}
output "secondary_vm_instance_name" {
  description = "Name of the secondary vSocket VM instance"
  value       = var.ha ? module.vsocket_gcp_ha.secondary_vm_instance_name : null
}
output "secondary_vm_mgmt_network_ip" {
  description = "Management network private IP of the secondary vSocket VM"
  value       = var.ha ? module.vsocket_gcp_ha.secondary_vm_mgmt_network_ip : null
}
output "secondary_vm_wan_network_ip" {
  description = "WAN network private IP of the secondary vSocket VM"
  value       = var.ha ? module.vsocket_gcp_ha.secondary_vm_wan_network_ip : null
}
output "secondary_vm_lan_network_ip" {
  description = "LAN network private IP of the secondary vSocket VM"
  value       = var.ha ? module.vsocket_gcp_ha.secondary_vm_lan_network_ip : null
}
output "secondary_vm_mgmt_public_ip" {
  description = "Management public IP of the secondary vSocket VM if assigned"
  value       = var.ha ? module.vsocket_gcp_ha.secondary_vm_mgmt_public_ip : null
}
output "secondary_vm_wan_public_ip" {
  description = "WAN public IP of the secondary vSocket VM if assigned"
  value       = var.ha ? module.vsocket_gcp_ha.secondary_vm_wan_public_ip : null
}
output "load_balancer_ip" {
  description = "IP address of the internal load balancer (floating IP)"
  value       = module.vsocket_gcp_ha.load_balancer_ip
}
output "load_balancer_name" {
  description = "Name of the load balancer forwarding rule"
  value       = module.vsocket_gcp_ha.load_balancer_name
}
output "vpc_mgmt_name" {
  description = "Name of the management VPC"
  value       = module.vsocket_gcp_ha.vpc_mgmt_name
}
output "vpc_wan_name" {
  description = "Name of the WAN VPC"
  value       = module.vsocket_gcp_ha.vpc_wan_name
}
output "vpc_lan_name" {
  description = "Name of the LAN VPC"
  value       = module.vsocket_gcp_ha.vpc_lan_name
}
output "vpc_lan_id" {
  description = "ID of the LAN VPC"
  value       = local.vpc_lan_id
}
output "vpc_lan_self_link" {
  description = "Self-link of the LAN VPC"
  value       = local.vpc_lan_self_link
}
output "subnet_mgmt_name" {
  description = "Name of the management subnet"
  value       = module.vsocket_gcp_ha.subnet_mgmt_name
}
output "subnet_wan_name" {
  description = "Name of the WAN subnet"
  value       = module.vsocket_gcp_ha.subnet_wan_name
}
output "subnet_lan_name" {
  description = "Name of the LAN subnet"
  value       = module.vsocket_gcp_ha.subnet_lan_name
}
output "primary_mgmt_static_ip" {
  description = "Primary management static IP address"
  value       = module.vsocket_gcp_ha.primary_mgmt_static_ip
}
output "primary_wan_static_ip" {
  description = "Primary WAN static IP address"
  value       = module.vsocket_gcp_ha.primary_wan_static_ip
}
output "secondary_mgmt_static_ip" {
  description = "Secondary management static IP address"
  value       = var.ha ? module.vsocket_gcp_ha.secondary_mgmt_static_ip : null
}
output "secondary_wan_static_ip" {
  description = "Secondary WAN static IP address"
  value       = var.ha ? module.vsocket_gcp_ha.secondary_wan_static_ip : null
}

# ------------------------------------------------------------------------------
# NCC outputs
# ------------------------------------------------------------------------------
output "ncc_hub_id" {
  description = "ID of the NCC hub. Client VPCs attach as spokes to this hub; client internet is allowed only via the security project (vSocket) for SASE."
  value       = google_network_connectivity_hub.ncc_hub.id
}

output "ncc_hub_name" {
  description = "Name of the NCC hub."
  value       = google_network_connectivity_hub.ncc_hub.name
}

output "ncc_security_spoke_id" {
  description = "ID of the security project VPC spoke attached to the NCC hub."
  value       = google_network_connectivity_spoke.ncc_security_spoke.id
}

output "ncc_client_spoke_ids" {
  description = "Map of client spoke logical names to their NCC spoke IDs."
  value       = { for k, s in google_network_connectivity_spoke.ncc_client_spoke : k => s.id }
}

output "ncc_hub_topology" {
  description = "Hub topology: STAR (spoke isolation) or MESH (default)."
  value       = var.ncc_spoke_isolation ? "STAR" : "MESH"
}

output "ncc_client_group_ids" {
  description = "Map of client spoke logical names to their effective hub group IDs (STAR: edge, MESH: null)."
  value       = { for k, _ in google_network_connectivity_spoke.ncc_client_spoke : k => local.ncc_edge_group_id }
}

# ------------------------------------------------------------------------------
# Cloud Router + BGP outputs
# ------------------------------------------------------------------------------
output "cloud_router_id" {
  description = "ID of the Cloud Router."
  value       = var.enable_cloud_router ? google_compute_router.lan_router[0].id : null
}

output "cloud_router_name" {
  description = "Name of the Cloud Router."
  value       = var.enable_cloud_router ? google_compute_router.lan_router[0].name : null
}

output "router_appliance_spoke_id" {
  description = "ID of the Router Appliance NCC spoke (vSocket registration)."
  value       = var.enable_cloud_router && var.enable_bgp ? google_network_connectivity_spoke.router_appliance[0].id : null
}

output "bgp_peer_status_command" {
  description = "gcloud command to check Cloud Router BGP session status."
  value = (
    var.enable_cloud_router
    ? "gcloud compute routers get-status ${google_compute_router.lan_router[0].name} --region=${var.region} --project=${local.security_project_id}"
    : null
  )
}

# ------------------------------------------------------------------------------
# Cato BGP peer outputs
# ------------------------------------------------------------------------------
output "cato_bgp_peer_primary_id" {
  description = "ID of the primary Cato BGP peer."
  value       = var.enable_cloud_router && var.enable_bgp && var.create_cato_bgp_peer ? cato_bgp_peer.primary[0].id : null
}

output "cato_bgp_peer_secondary_id" {
  description = "ID of the secondary Cato BGP peer (HA)."
  value       = local.enable_secondary_bgp && var.create_cato_bgp_peer ? cato_bgp_peer.secondary[0].id : null
}
