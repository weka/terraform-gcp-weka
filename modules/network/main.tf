locals {
  vpcs_number = length(var.subnets) > 0 ? length(var.subnets) : length(var.subnets_range)
  temp = flatten([
    for from in range(local.vpcs_number) : [
      for to in range(local.vpcs_number) : {
        from = from
        to   = to
      }
    ]
  ])
  peering_list = [for t in local.temp : t if t["from"] != t["to"]]
}

# ====================== vpc ==============================
resource "google_project_service" "project_compute" {
  project                    = var.project_id
  service                    = "compute.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [google_project_service.project_gcp_api]
}

resource "google_project_service" "project_gcp_api" {
  project                    = var.project_id
  service                    = "iam.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "service_cloud_api" {
  project                    = var.project_id
  service                    = "cloudresourcemanager.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

data "google_compute_network" "vpc_list_ids" {
  count = length(var.vpcs)
  name  = var.vpcs[count.index]
}

data "google_compute_subnetwork" "subnets_list_ids" {
  count = length(var.subnets)
  name  = var.subnets[count.index]
}


resource "google_compute_network" "vpc_network" {
  count                           = length(var.vpcs) == 0 ? local.vpcs_number : 0
  name                            = "${var.prefix}-vpc-${count.index}"
  auto_create_subnetworks         = false
  mtu                             = var.mtu_size
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = var.subnet_autocreate_as_private
  depends_on                      = [google_project_service.project_compute, google_project_service.project_gcp_api]
}

# ======================= subnet ==========================
resource "google_compute_subnetwork" "subnetwork" {
  count                    = length(var.subnets) == 0 ? local.vpcs_number : 0
  name                     = "${var.prefix}-subnet-${count.index}"
  ip_cidr_range            = var.subnets_range[count.index]
  region                   = var.region
  network                  = length(var.vpcs) == 0 ? google_compute_network.vpc_network[count.index].name : data.google_compute_network.vpc_list_ids[count.index].name
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "psc_subnetwork" {
  count                    = var.subnet_autocreate_as_private ? 1 : 0
  name                     = "${var.prefix}-subnet-vpc-access"
  purpose                  = "PRIVATE_SERVICE_CONNECT"
  ip_cidr_range            = var.psc_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc_network[0].name
  private_ip_google_access = true
  depends_on               = [google_compute_network.vpc_network]
}

resource "google_compute_network_peering" "peering" {
  count        = var.set_peering ? length(local.peering_list) : 0
  name         = "${var.prefix}-peering-${local.peering_list[count.index]["from"]}-${local.peering_list[count.index]["to"]}"
  network      = length(var.vpcs) == 0 ? google_compute_network.vpc_network[local.peering_list[count.index]["from"]].self_link : data.google_compute_network.vpc_list_ids[local.peering_list[count.index]["from"]].self_link
  peer_network = length(var.vpcs) == 0 ? google_compute_network.vpc_network[local.peering_list[count.index]["to"]].self_link : data.google_compute_network.vpc_list_ids[local.peering_list[count.index]["to"]].self_link
  depends_on   = [google_compute_subnetwork.subnetwork]
}

# ========================= sg =================================
resource "google_compute_firewall" "sg_ssh" {
  count         = length(var.allow_ssh_cidrs) == 0 ? 0 : local.vpcs_number
  name          = "${var.prefix}-sg-ssh-${count.index}"
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[count.index].name : data.google_compute_network.vpc_list_ids[count.index].name
  source_ranges = var.allow_ssh_cidrs
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_tags = ["ssh"]
}

resource "google_compute_firewall" "sg_weka_api" {
  count         = length(var.allow_weka_api_cidrs) == 0 ? 0 : local.vpcs_number
  name          = "${var.prefix}-sg-weka-api-${count.index}"
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[count.index].name : data.google_compute_network.vpc_list_ids[count.index].name
  source_ranges = var.allow_weka_api_cidrs
  allow {
    protocol = "tcp"
    ports    = ["14000"]
  }
  source_tags = ["weka-api"]
  target_tags = ["backends"]
}

resource "google_compute_firewall" "sg_private" {
  count         = length(var.vpcs) == 0 ? length(google_compute_network.vpc_network) : length(var.vpcs)
  name          = "${var.prefix}-sg-all-${count.index}"
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[count.index].name : data.google_compute_network.vpc_list_ids[count.index].id
  source_ranges = length(var.vpcs) == 0 ? google_compute_subnetwork.subnetwork.*.ip_cidr_range : data.google_compute_subnetwork.subnets_list_ids.*.ip_cidr_range
  allow {
    protocol = "all"
  }
  target_tags = ["backends"]
}

#================ Vpc connector ==========================
resource "google_project_service" "project_vpc" {
  project                    = var.project_id
  service                    = "vpcaccess.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [google_project_service.project_gcp_api]
}

resource "google_vpc_access_connector" "connector" {
  count         = var.vpc_connector_name == "" ? 1 : 0
  name          = "${var.prefix}-connector"
  ip_cidr_range = var.vpc_connector_range
  region        = lookup(var.vpc_connector_region_map, var.region, var.region)
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[0].id : data.google_compute_network.vpc_list_ids[count.index].id
  depends_on    = [google_project_service.project_vpc]
}

#============== Health check ============================
resource "google_compute_firewall" "fw_hc" {
  name      = "${var.prefix}-fw-allow-hc"
  direction = "INGRESS"
  network   = length(var.vpcs) == 0 ? google_compute_network.vpc_network[0].self_link : data.google_compute_network.vpc_list_ids[0].self_link
  allow {
    protocol = "all"
  }
  # allow all access from GCP internal health check ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "35.235.240.0/20"]
  source_tags   = ["allow-health-check"]
}

resource "google_compute_firewall" "fw_cloud_run" {
  name      = "${var.prefix}-fw-allow-cloud-run"
  direction = "INGRESS"
  network   = length(var.vpcs) == 0 ? google_compute_network.vpc_network[0].self_link : data.google_compute_network.vpc_list_ids[0].self_link
  allow {
    protocol = "all"
  }
  # allow all access from GCP internal cloud run ranges
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["all-apis", "vpc-connector", "backends"]
}

# allow communication within the subnet
resource "google_compute_firewall" "fw_ilb_to_backends" {
  name          = "${var.prefix}-fw-allow-ilb-to-backends"
  direction     = "INGRESS"
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[0].self_link : data.google_compute_network.vpc_list_ids[0].self_link
  source_ranges = length(var.vpcs) == 0 ? [var.subnets_range[0]] : [data.google_compute_subnetwork.subnets_list_ids[0].ip_cidr_range]
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

# =================== private DNS ==========================
locals {
  network_list = length(var.vpcs) == 0 ? google_compute_network.vpc_network.*.self_link : data.google_compute_network.vpc_list_ids.*.self_link
}

resource "google_project_service" "project_dns" {
  project                    = var.project_id
  service                    = "dns.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_dns_managed_zone" "private_zone" {
  count       = var.private_zone_name == "" ? 1 : 0
  name        = "${var.prefix}-private-zone"
  dns_name    = "${var.prefix}.private.net."
  project     = var.project_id
  description = "private dns weka.private.net"
  visibility  = "private"

  private_visibility_config {
    dynamic "networks" {
      for_each = local.network_list
      content {
        network_url = networks.value
      }
    }
  }
  depends_on = [google_project_service.project_dns]
}

# private private service connect
resource "google_project_service" "psc" {
  count                      = var.subnet_autocreate_as_private ? 1 : 0
  service                    = "servicenetworking.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = true
}

resource "google_compute_route" "restricted_googleapis_route" {
  count            = var.subnet_autocreate_as_private ? 1 : 0
  name             = "${var.prefix}-restricted-googleapis-route"
  dest_range       = "199.36.153.4/30"
  network          = google_compute_network.vpc_network[0].name
  next_hop_gateway = "projects/${var.project_id}/global/gateways/default-internet-gateway"
  priority         = 1000
}

resource "google_compute_route" "private_googleapis_route" {
  count            = var.subnet_autocreate_as_private ? 1 : 0
  name             = "${var.prefix}-private-googleapis-route"
  dest_range       = "199.36.153.8/30"
  network          = google_compute_network.vpc_network[0].name
  next_hop_gateway = "projects/${var.project_id}/global/gateways/default-internet-gateway"
  priority         = 1000
}

resource "google_compute_global_address" "vpcsc_ip" {
  count        = var.subnet_autocreate_as_private ? 1 : 0
  project      = var.project_id
  name         = "${var.prefix}-vpcsc-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.vpc_network[0].self_link
  address      = var.endpoint_vpcsc_internal_ip_address
  depends_on   = [google_compute_network.vpc_network]
}

resource "google_compute_global_address" "apis_ip" {
  count        = var.subnet_autocreate_as_private ? 1 : 0
  project      = var.project_id
  name         = "${var.prefix}-apis-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.vpc_network[0].self_link
  address      = var.endpoint_apis_internal_ip_address
  depends_on   = [google_compute_network.vpc_network]
}

resource "google_compute_global_forwarding_rule" "apis_forwarding_rule" {
  count                 = var.subnet_autocreate_as_private ? 1 : 0
  project               = var.project_id
  name                  = "${var.prefix}apis"
  target                = "all-apis"
  network               = google_compute_network.vpc_network[0].self_link
  ip_address            = google_compute_global_address.apis_ip[0].id
  load_balancing_scheme = ""
  depends_on            = [google_compute_global_address.apis_ip]
}

resource "google_compute_global_forwarding_rule" "vpcsc_forwarding_rule" {
  count                 = var.subnet_autocreate_as_private ? 1 : 0
  project               = var.project_id
  name                  = "${var.prefix}vpcsc"
  target                = "vpc-sc"
  network               = google_compute_network.vpc_network[0].self_link
  ip_address            = google_compute_global_address.vpcsc_ip[0].id
  load_balancing_scheme = ""
  depends_on            = [google_compute_global_address.vpcsc_ip]
}

resource "google_compute_firewall" "allow_endpoint_sg" {
  count         = var.subnet_autocreate_as_private ? 1 : 0
  name          = "${var.prefix}-allow-endpoint-sg"
  direction     = "INGRESS"
  network       = length(var.vpcs) == 0 ? google_compute_network.vpc_network[0].name : data.google_compute_network.vpc_list_ids[0].id
  source_ranges = [var.endpoint_apis_internal_ip_address, var.endpoint_vpcsc_internal_ip_address]
  allow {
    protocol = "all"
  }
  source_tags = ["all-apis", "backends"]
  depends_on  = [google_compute_network.vpc_network]
}

resource "google_dns_managed_zone" "cloud_run_zone" {
  count       = var.subnet_autocreate_as_private && var.cloud_run_dns_zone_name == "" ? 1 : 0
  name        = "${var.prefix}-psc"
  dns_name    = "run.app."
  project     = var.project_id
  description = "Private DNS of run.app."
  visibility  = "private"

  private_visibility_config {
    dynamic "networks" {
      for_each = local.network_list
      content {
        network_url = networks.value
      }
    }
  }
  depends_on = [google_project_service.project_dns, google_compute_network.vpc_network]
}

resource "google_dns_record_set" "cloud_run_endpoint_record" {
  count        = var.subnet_autocreate_as_private ? 1 : 0
  name         = "*.run.app."
  managed_zone = var.cloud_run_dns_zone_name == "" ? google_dns_managed_zone.cloud_run_zone[0].name : var.cloud_run_dns_zone_name
  project      = var.project_id
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.vpcsc_ip[0].address]
  depends_on   = [google_dns_managed_zone.cloud_run_zone, google_compute_global_address.vpcsc_ip, google_compute_network.vpc_network]
}

resource "google_dns_managed_zone" "googleapis_zone" {
  count       = var.subnet_autocreate_as_private && var.googleapis_dns_zone_name == "" ? 1 : 0
  name        = "${var.prefix}-apis"
  dns_name    = "googleapis.com."
  project     = var.project_id
  description = "Private DNS of googleapis.com."
  visibility  = "private"

  private_visibility_config {
    dynamic "networks" {
      for_each = local.network_list
      content {
        network_url = networks.value
      }
    }
  }
  depends_on = [google_project_service.project_dns, google_compute_network.vpc_network]
}

resource "google_dns_record_set" "apis_endpoint_record" {
  count        = var.subnet_autocreate_as_private ? 1 : 0
  name         = "*.googleapis.com."
  managed_zone = var.googleapis_dns_zone_name == "" ? google_dns_managed_zone.googleapis_zone[0].name : var.googleapis_dns_zone_name
  project      = var.project_id
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.apis_ip[0].address]
  depends_on   = [google_dns_managed_zone.googleapis_zone, google_compute_global_address.apis_ip, google_compute_network.vpc_network]
}
