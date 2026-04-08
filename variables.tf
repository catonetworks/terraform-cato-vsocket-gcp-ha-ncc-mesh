# ------------------------------------------------------------------------------
# vSocket GCP HA module source (pass-through)
# ------------------------------------------------------------------------------
variable "vsocket_module_source" {
  description = "Source for the Cato vSocket GCP HA Terraform module (path or registry). Use ../terraform-cato-vsocket-gcp-ha when the two modules are side by side."
  type        = string
  default     = "../terraform-cato-vsocket-gcp-ha"
}

# ------------------------------------------------------------------------------
# All variables below are passed through to the vsocket GCP HA module
# ------------------------------------------------------------------------------

variable "token" {
  description = "API token used to authenticate with the Cato Networks API."
  type        = string
  sensitive   = true
}

variable "account_id" {
  description = "Account ID used for the Cato Networks integration."
  type        = number
  default     = null
  validation {
    condition     = var.account_id == null || (var.account_id > 0 && var.account_id < 2147483648)
    error_message = "Account ID must be a positive integer less than 2147483648."
  }
}

variable "baseurl" {
  description = "Base URL for the Cato Networks API."
  type        = string
  default     = "https://api.catonetworks.com/api/v1/graphql2"
  validation {
    condition     = can(regex("^https?://[a-zA-Z0-9.-]+(/.*)?$", var.baseurl))
    error_message = "Base URL must be a valid HTTP/HTTPS URL."
  }
}

variable "site_name" {
  description = "Name of the vsocket site"
  type        = string
}

variable "site_description" {
  description = "Description of the vsocket site"
  type        = string
}

variable "site_location" {
  description = "Site location information. If all fields are null, location will be automatically determined from the GCP region."
  type = object({
    city         = optional(string)
    country_code = optional(string)
    state_code   = optional(string)
    timezone     = optional(string)
  })
  default = {
    city         = null
    country_code = null
    state_code   = null
    timezone     = null
  }
  validation {
    condition = (
      (var.site_location.city == null && var.site_location.country_code == null &&
      var.site_location.state_code == null && var.site_location.timezone == null) ||
      (var.site_location.city != null && var.site_location.country_code != null &&
      var.site_location.timezone != null)
    )
    error_message = "Site location must either have all fields null (for automatic lookup) or provide at minimum city, country_code, and timezone."
  }
}

variable "site_type" {
  description = "The type of the site"
  type        = string
  default     = "CLOUD_DC"
  validation {
    condition     = contains(["DATACENTER", "BRANCH", "CLOUD_DC", "HEADQUARTERS"], var.site_type)
    error_message = "The site_type variable must be one of 'DATACENTER','BRANCH','CLOUD_DC','HEADQUARTERS'."
  }
}

variable "region" {
  description = "GCP Region"
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "Region must be in the format: region-location (e.g., us-central1)."
  }
}

variable "primary_zone" {
  description = "GCP Zone of Primary vSocket"
  type        = string
  default     = null
}

variable "secondary_zone" {
  description = "GCP Zone of Secondary vSocket"
  type        = string
  default     = null
}

variable "vpc_mgmt_name" {
  type    = string
  default = null
}
variable "vpc_wan_name" {
  type    = string
  default = null
}
variable "vpc_lan_name" {
  type    = string
  default = null
}
variable "subnet_mgmt_name" {
  type    = string
  default = null
}
variable "subnet_wan_name" {
  type    = string
  default = null
}
variable "subnet_lan_name" {
  type    = string
  default = null
}

variable "subnet_mgmt_cidr" {
  description = "Management Subnet CIDR"
  type        = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.subnet_mgmt_cidr))
    error_message = "Management Subnet CIDR must be a valid IPv4 CIDR notation."
  }
}
variable "subnet_wan_cidr" {
  description = "WAN Subnet CIDR"
  type        = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.subnet_wan_cidr))
    error_message = "WAN Subnet CIDR must be a valid IPv4 CIDR notation."
  }
}
variable "subnet_lan_cidr" {
  description = "LAN Subnet CIDR"
  type        = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.subnet_lan_cidr))
    error_message = "LAN Subnet CIDR must be a valid IPv4 CIDR notation."
  }
}

variable "ip_mgmt_name" {
  type    = string
  default = null
}
variable "ip_wan_name" {
  type    = string
  default = null
}

variable "boot_disk_size" {
  type    = number
  default = 20
  validation {
    condition     = var.boot_disk_size >= 10 && var.boot_disk_size <= 65536
    error_message = "Boot disk size must be between 10 GB and 65536 GB."
  }
}
variable "boot_disk_image" {
  type    = string
  default = "projects/cato-vsocket-production/global/images/gcp-socket-image-v22-0-19207"
  validation {
    condition     = can(regex("^projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/global/images/[a-z0-9-]+$", var.boot_disk_image))
    error_message = "Boot disk image must be a valid GCP image path."
  }
}
variable "machine_type" {
  type    = string
  default = "n2-standard-4"
  validation {
    condition     = can(regex("^[a-z][0-9]-[a-z]+-[0-9]+$", var.machine_type))
    error_message = "Machine type must be in the format: family-series-size (e.g., n2-standard-4)."
  }
}
variable "vm_name" {
  type    = string
  default = null
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.vm_name)) || var.vm_name == null
    error_message = "VM name must be 1-63 characters long, start with a letter, and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "network_tier" {
  type    = string
  default = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "PREMIUM"], var.network_tier)
    error_message = "Network tier must be either 'STANDARD' or 'PREMIUM'."
  }
}

variable "mgmt_network_ip_primary" { type = string }
variable "mgmt_network_ip_secondary" { type = string }
variable "wan_network_ip_primary" { type = string }
variable "wan_network_ip_secondary" { type = string }
variable "lan_network_ip_primary" { type = string }
variable "lan_network_ip_secondary" { type = string }
variable "load_balancer_ip" { type = string }

variable "public_ip_mgmt" {
  type    = bool
  default = true
}
variable "public_ip_wan" {
  type    = bool
  default = true
}

variable "lan_firewall_rule_name" {
  type    = string
  default = "allow-private-ranges-traffic-in-lan-subnet-fw-rule"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.lan_firewall_rule_name))
    error_message = "Firewall rule name must be 1-63 characters, start with a letter, and contain only lowercase letters, numbers, or hyphens."
  }
}
variable "create_firewall_rule" {
  type    = bool
  default = true
}

variable "labels" {
  type    = map(string)
  default = {}
}
variable "tags" {
  type    = list(string)
  default = []
}

variable "license_id" {
  type    = string
  default = null
}
variable "license_bw" {
  type    = string
  default = null
}

variable "enable_static_range_translation" {
  type    = string
  default = false
}

variable "routed_networks" {
  type = map(object({
    subnet            = string
    translated_subnet = optional(string)
    gateway           = optional(string)
    interface_index   = optional(string, "LAN1")
  }))
  default = {}
}

variable "upstream_bandwidth" {
  type    = string
  default = "null"
}
variable "downstream_bandwidth" {
  type    = string
  default = "null"
}

# ------------------------------------------------------------------------------
# NCC-specific variables
# ------------------------------------------------------------------------------
variable "ncc_hub_name" {
  description = "Name of the NCC hub. If null, defaults to \"{site_name}-ncc-hub\"."
  type        = string
  default     = null
}

variable "ncc_security_spoke_export_ranges" {
  description = "CIDR ranges to export from the security project LAN VPC to other spokes. If null, defaults to [subnet_lan_cidr]. 0.0.0.0/0 is always added so client internet goes only via the vSocket (SASE)."
  type        = list(string)
  default     = null
}

variable "ncc_client_traffic_source_ranges" {
  description = "CIDR ranges that identify client-originated traffic in the security LAN VPC (via NCC). If empty, derived from all ncc_client_spokes export_ranges."
  type        = list(string)
  default     = []
}

variable "ncc_spoke_isolation" {
  description = "Switch hub to STAR preset topology (center/edge groups). Optional — most setups use MESH (default) with BGP route injection for traffic inspection. Warning: changing on an existing hub forces hub recreation."
  type        = bool
  default     = false
}

variable "ncc_client_spokes" {
  description = <<-EOT
    Map of client project spokes to create and attach to the NCC hub. Key is a logical spoke name. Each value must have:
    - project_id: GCP project ID where the VPC lives (spoke is created in this project).
    - vpc_network_uri: Self-link of the VPC to attach.
    - export_ranges (optional): List of CIDR ranges to export from this VPC to other spokes.
    The Terraform identity must have roles/networkconnectivity.spokeAdmin in each client project.
    EOT
  type = map(object({
    project_id      = string
    vpc_network_uri = string
    export_ranges   = optional(list(string))
  }))
  default = {}
}

# ------------------------------------------------------------------------------
# Cloud Router + BGP variables
# ------------------------------------------------------------------------------
# Enables a Cloud Router in the LAN VPC with optional BGP peering to the Cato
# vSocket(s) via the NCC Router Appliance pattern. Routes learned from the
# vSocket become dynamic routes in the LAN VPC and propagate through the NCC
# Hub to client spoke VPCs, solving the return-routing problem (GCP → on-prem).
# ------------------------------------------------------------------------------

variable "enable_cloud_router" {
  description = "Create a Cloud Router in the LAN VPC. Required for BGP route advertisement to NCC Hub."
  type        = bool
  default     = false
}

variable "cloud_router_name" {
  description = "Name of the Cloud Router. Defaults to \"{site_name}-lan-router\"."
  type        = string
  default     = null
}

variable "cloud_router_asn" {
  description = "BGP ASN for the Cloud Router."
  type        = number
  default     = 64520
  validation {
    condition     = var.cloud_router_asn >= 64512 && var.cloud_router_asn <= 65534
    error_message = "ASN must be in private range 64512-65534."
  }
}

variable "cloud_router_advertised_ip_ranges" {
  description = "IP ranges for the Cloud Router to advertise to BGP peers (e.g. GCP subnets the vSocket should know about). When non-empty, advertise_mode is set to CUSTOM; otherwise DEFAULT (all VPC subnets) is used."
  type = list(object({
    range       = string
    description = optional(string, "")
  }))
  default = []
}

variable "enable_bgp" {
  description = "Enable BGP peering between Cloud Router and Cato vSocket(s) via NCC Router Appliance. Requires enable_cloud_router = true and primary_zone to be set."
  type        = bool
  default     = false
}

variable "cato_bgp_asn" {
  description = "BGP ASN of the Cato vSocket."
  type        = number
  default     = 64515
  validation {
    condition     = var.cato_bgp_asn >= 64512 && var.cato_bgp_asn <= 65534
    error_message = "ASN must be in private range 64512-65534."
  }
}

variable "cloud_router_bgp_interface_ip_primary" {
  description = "Private IP for the Cloud Router primary BGP interface. Must be an available IP in the LAN subnet. Required when enable_bgp = true."
  type        = string
  default     = null
}

variable "cloud_router_bgp_interface_ip_secondary" {
  description = "Private IP for the Cloud Router secondary (redundant) BGP interface. Must be in the LAN subnet. When set, enables HA BGP peering with both vSocket VMs."
  type        = string
  default     = null
}

variable "advertised_route_priority" {
  description = "BGP advertised route priority for the primary peer (lower = preferred). Secondary peer automatically uses this value + 100."
  type        = number
  default     = 100
}

variable "enable_bfd" {
  description = "Enable BFD (Bidirectional Forwarding Detection) on BGP peers for sub-second failure detection."
  type        = bool
  default     = true
}

variable "bfd_min_transmit_interval" {
  description = "BFD minimum transmit interval in milliseconds."
  type        = number
  default     = 1000
}

variable "bfd_min_receive_interval" {
  description = "BFD minimum receive interval in milliseconds."
  type        = number
  default     = 1000
}

variable "bfd_multiplier" {
  description = "BFD detection multiplier (session declared down after multiplier consecutive missed packets)."
  type        = number
  default     = 5
  validation {
    condition     = var.bfd_multiplier >= 5 && var.bfd_multiplier <= 16
    error_message = "BFD multiplier must be between 5 and 16."
  }
}

variable "create_bgp_firewall_rule" {
  description = "Create firewall rules allowing BGP (TCP/179) and BFD (UDP/3784-3785) traffic between Cloud Router and vSocket in the LAN VPC."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Cato BGP peer (vSocket-side BGP configuration via Cato API)
# ------------------------------------------------------------------------------
# Automates the Cato-side BGP peer setup so vSocket knows how to peer with the
# Cloud Router and which routes to advertise back. Without this, vSocket must be
# configured manually in the Cato Management Application.
# ------------------------------------------------------------------------------

variable "create_cato_bgp_peer" {
  description = "Create cato_bgp_peer resources for automatic Cato-side BGP configuration. Requires enable_bgp = true."
  type        = bool
  default     = true
}

variable "cato_bgp_peer_default_action" {
  description = "Default action for routes not matching filters on the Cato BGP peer (ACCEPT or DROP)."
  type        = string
  default     = "ACCEPT"
  validation {
    condition     = contains(["ACCEPT", "DROP"], var.cato_bgp_peer_default_action)
    error_message = "Must be ACCEPT or DROP."
  }
}

variable "cato_bgp_peer_advertise_default_route" {
  description = "Advertise default route (0.0.0.0/0) from vSocket to Cloud Router. Essential for steering internet-bound and inter-spoke traffic through vSocket."
  type        = bool
  default     = true
}

variable "cato_bgp_peer_advertise_all_routes" {
  description = "Advertise all Cato routes to the Cloud Router."
  type        = bool
  default     = false
}

variable "cato_bgp_peer_summary_routes" {
  description = "Summary routes to advertise from vSocket to Cloud Router (e.g. client CIDRs for inter-spoke inspection). Each entry has a route (CIDR) and optional community list."
  type = list(object({
    route = string
    community = optional(list(object({
      from = number
      to   = number
    })), [])
  }))
  default = []
}

variable "cato_bgp_peer_metric" {
  description = "Route preference metric for the Cato BGP peer (lower = preferred)."
  type        = number
  default     = 150
}

variable "enable_cato_bfd" {
  description = "Enable BFD settings on cato_bgp_peer resources. Keep false for CLOUD_DC sites because Cato API allows BFD only for cloud interconnect and ipsec sites."
  type        = bool
  default     = false
}
