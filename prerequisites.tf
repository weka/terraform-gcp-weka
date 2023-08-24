

module "service_account" {
  count             = var.sa_email == null ? 1 : 0
  source            = "./modules/service_account"
  project_id        = var.project_id
  prefix            = var.prefix
  cluster_name      = var.cluster_name
  obs_name          = var.obs_name
  state_bucket_name = var.state_bucket_name
}

module "network" {
  count               = length(var.subnets_name) == 0 ? 1 : 0
  source              = "./modules/network"
  project_id          = var.project_id
  prefix              = var.prefix
  region              = var.region
  subnets_range       = var.subnets_range
  zone                = var.zone
  vpc_connector_range = var.vpc_connector_range
  allow_ssh_ranges    = var.allow_ssh_ranges
  private_network     = var.private_network
  depends_on          = [module.service_account]
}

locals {
  vpc_connector     = var.vpc_connector_name == null ? module.network[0].vpc_connector_name : var.vpc_connector_name
  sa_email          = var.sa_email == null ? module.service_account[0].service_account_email : var.sa_email
  subnets_name      = length(var.subnets_name) == 0 ? module.network[0].subnetwork_name : var.subnets_name
  private_zone_name = var.private_zone_name == null ? module.network[0].private_zone_name : var.private_zone_name
  private_dns_name  = var.private_dns_name == null ? module.network[0].private_dns_name : var.private_dns_name
  vpcs_name         = length(var.vpcs_name) == 0 ? module.network[0].vpcs_names : var.vpcs_name
}

module "worker_pool" {
  count               = var.create_worker_pool ? 1 : 0
  source              = "./modules/worker_pool"
  project_id          = var.project_id
  region              = var.region
  vpc_name            = local.vpcs_name[0]
  cluster_name        = var.cluster_name
  sa_email            = local.sa_email
  worker_pool_network = var.worker_pool_network
  set_worker_pool_network_peering = var.set_worker_pool_network_peering
  depends_on          = [module.network, google_project_service.cloud-build-api, google_project_service.compute-api]
}

#resource "time_sleep" "wait_30_seconds" {
 # depends_on = [module.network, module.service_account, module.shared_vpc_peering, module.worker_pool]
  #create_duration = "30s"
#}

data "google_compute_network" "this"{
  count      = length(var.vpcs_name) == 0 ? length(module.network[0].vpcs_names) : length(var.vpcs_name)
  name       = length(var.vpcs_name) == 0 ? module.network[0].vpcs_names[count.index] : var.vpcs_name[count.index]
  depends_on = [module.network]#[module.network, time_sleep.wait_30_seconds]
}

data "google_compute_subnetwork" "this" {
  count      = length(var.subnets_name) == 0 ? length(module.network[0].subnetwork_name) : length(var.subnets_name)
  name       = length(var.subnets_name) == 0 ? module.network[0].subnetwork_name[count.index] : var.subnets_name[count.index]
  depends_on = [module.network]#[module.network, time_sleep.wait_30_seconds]
}

provider "google" {
  alias   = "shared-vpc"
  project = var.host_project
  region  = var.region
}

module "shared_vpc_peering" {
  count               = var.host_project != null ? 1 : 0
  source              = "./modules/shared_vpcs"
  project_id          = var.project_id
  host_project        = var.host_project
  shared_vpcs         = var.shared_vpcs
  vpcs_name           = local.vpcs_name
  sa_email            = local.sa_email
  host_shared_range   = var.host_shared_range
  providers = {
    google.shared-vpc = google.shared-vpc
  }
  depends_on = [module.network]
}
