module "service_account" {
  count             = var.sa_email == "" ? 1 : 0
  source            = "./modules/service_account"
  project_id        = var.project_id
  prefix            = var.prefix
  cluster_name      = var.cluster_name
  obs_name          = var.obs_name
  state_bucket_name = var.state_bucket_name
}

module "network" {
  count                 = length(var.subnets_name) == 0 ? 1 : 0
  source                = "./modules/network"
  project_id            = var.project_id
  prefix                = var.prefix
  region                = var.region
  subnets_range         = var.subnets_range
  vpc_connector_range   = var.vpc_connector_range
  vpc_connector_name    = var.vpc_connector_name
  allow_ssh_ranges      = var.allow_ssh_ranges
  allow_weka_api_ranges = var.allow_weka_api_ranges
  vpcs_number           = var.vpcs_number
  private_zone_name     = var.private_zone_name
  mtu_size              = var.mtu_size
  depends_on            = [module.service_account]
}

locals {
  vpc_connector     = var.vpc_connector_name == "" ? module.network[0].vpc_connector_name : var.vpc_connector_name
  sa_email          = var.sa_email == "" ? module.service_account[0].service_account_email : var.sa_email
  subnets_name      = length(var.subnets_name) == 0 ? module.network[0].subnetwork_name : var.subnets_name
  private_zone_name = var.private_zone_name == "" ? module.network[0].private_zone_name : var.private_zone_name
  private_dns_name  = var.private_dns_name == "" ? module.network[0].private_dns_name : var.private_dns_name
  vpcs_name         = length(var.vpcs_name) == 0 ? module.network[0].vpcs_names : var.vpcs_name
}

module "worker_pool" {
  count                           = var.create_worker_pool ? 1 : 0
  source                          = "./modules/worker_pool"
  project_id                      = var.project_id
  prefix                          = var.prefix
  worker_machine_type             = var.worker_machine_type
  worker_disk_size                = var.worker_disk_size
  region                          = var.region
  vpc_name                        = local.vpcs_name[0]
  cluster_name                    = var.cluster_name
  sa_email                        = local.sa_email
  worker_pool_network             = var.worker_pool_network
  worker_pool_name                = var.worker_pool_name
  set_worker_pool_network_peering = var.set_worker_pool_network_peering
  depends_on = [
    module.network, google_project_service.cloud_build_api, google_project_service.compute_api
  ]
}

data "google_compute_network" "this" {
  count      = length(var.vpcs_name) == 0 ? length(module.network[0].vpcs_names) : length(var.vpcs_name)
  name       = length(var.vpcs_name) == 0 ? module.network[0].vpcs_names[count.index] : var.vpcs_name[count.index]
  depends_on = [module.network]
}

data "google_compute_subnetwork" "this" {
  count      = length(var.subnets_name) == 0 ? length(module.network[0].subnetwork_name) : length(var.subnets_name)
  name       = length(var.subnets_name) == 0 ? module.network[0].subnetwork_name[count.index] : var.subnets_name[count.index]
  depends_on = [module.network]
}


module "shared_vpc_peering" {
  count             = var.host_project == "" ? 0 : 1
  source            = "./modules/shared_vpcs"
  project_id        = var.project_id
  prefix            = var.prefix
  host_project      = var.host_project
  shared_vpcs       = var.shared_vpcs
  vpcs_name         = local.vpcs_name
  sa_email          = local.sa_email
  host_shared_range = var.host_shared_range
  depends_on        = [module.network]
}