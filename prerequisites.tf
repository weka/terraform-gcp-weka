module "service_account" {
  count                = var.sa_email == "" ? 1 : 0
  source               = "./modules/service_account"
  project_id           = var.project_id
  prefix               = var.prefix
  cluster_name         = var.cluster_name
  tiering_obs_name     = var.tiering_obs_name
  state_bucket_name    = var.state_bucket_name
  weka_tar_bucket_name = var.weka_tar_bucket_name
  weka_tar_project_id  = var.weka_tar_project_id
  network_project_id   = var.network_project_id
}

module "network" {
  count                              = length(var.subnets_name) == 0 ? 1 : 0
  source                             = "./modules/network"
  project_id                         = var.project_id
  prefix                             = var.prefix
  region                             = var.region
  subnets_range                      = var.subnets_range
  vpc_connector_range                = var.vpc_connector_range
  vpc_connector_id                   = var.vpc_connector_id
  allow_ssh_cidrs                    = var.allow_ssh_cidrs
  allow_weka_api_cidrs               = var.allow_weka_api_cidrs
  private_zone_name                  = var.private_zone_name
  mtu_size                           = var.mtu_size
  subnet_autocreate_as_private       = var.subnet_autocreate_as_private
  endpoint_apis_internal_ip_address  = var.endpoint_apis_internal_ip_address
  endpoint_vpcsc_internal_ip_address = var.endpoint_vpcsc_internal_ip_address
  cloud_run_dns_zone_name            = var.cloud_run_dns_zone_name
  googleapis_dns_zone_name           = var.googleapis_dns_zone_name
  psc_subnet_cidr                    = var.psc_subnet_cidr
  network_project_id                 = var.network_project_id
  set_peering                        = var.set_peering
  vpcs                               = var.vpcs_name
  create_nat_gateway                 = var.create_nat_gateway
  depends_on                         = [module.service_account]
}

locals {
  sa_email           = var.sa_email == "" ? module.service_account[0].service_account_email : var.sa_email
  subnets_name       = length(var.subnets_name) == 0 ? module.network[0].subnetwork_name : var.subnets_name
  private_zone_name  = var.private_zone_name == "" ? module.network[0].private_zone_name : var.private_zone_name
  private_dns_name   = var.private_dns_name == "" ? module.network[0].private_dns_name : var.private_dns_name
  vpcs_name          = length(var.vpcs_name) == 0 ? module.network[0].vpcs_names : var.vpcs_name
  network_project_id = var.network_project_id != "" ? var.network_project_id : var.project_id
  vpc_connector_id   = var.vpc_connector_id == "" ? module.network[0].vpc_connector_id : var.vpc_connector_id
}

module "worker_pool" {
  count                        = var.create_worker_pool ? 1 : 0
  source                       = "./modules/worker_pool"
  project_id                   = var.project_id
  prefix                       = var.prefix
  worker_machine_type          = var.worker_machine_type
  worker_disk_size             = var.worker_disk_size
  region                       = var.region
  vpc_name                     = local.vpcs_name[0]
  cluster_name                 = var.cluster_name
  worker_address               = var.worker_pool_address_cidr
  worker_pool_id               = var.worker_pool_id
  network_project_id           = local.network_project_id
  worker_address_prefix_length = var.worker_address_prefix_length
  depends_on = [
    module.network, google_project_service.cloud_build_api, google_project_service.compute_api
  ]
}

data "google_compute_network" "this" {
  count      = length(local.vpcs_name)
  project    = local.network_project_id
  name       = local.vpcs_name[count.index]
  depends_on = [module.network]
}

data "google_compute_subnetwork" "this" {
  count      = length(local.subnets_name)
  project    = local.network_project_id
  name       = local.subnets_name[count.index]
  depends_on = [module.network]
}

resource "google_compute_shared_vpc_host_project" "shared_vpc_host" {
  count   = var.enable_shared_vpc_host_project ? 1 : 0
  project = var.host_project
}

resource "google_compute_shared_vpc_service_project" "shared_vpc_service" {
  count           = var.enable_shared_vpc_host_project ? 1 : 0
  host_project    = var.host_project
  service_project = var.project_id
  depends_on      = [google_compute_shared_vpc_host_project.shared_vpc_host]
}

module "vpc_peering" {
  count                                = length(var.vpcs_to_peer_to_deployment_vpc) > 0 ? 1 : 0
  source                               = "./modules/vpc_peering"
  project_id                           = local.network_project_id
  prefix                               = var.prefix
  vpc_to_peer_project_id               = var.vpc_to_peer_project_id
  vpcs_to_peer_to_deployment_vpc       = var.vpcs_to_peer_to_deployment_vpc
  vpcs_name                            = local.vpcs_name
  vpcs_range_to_peer_to_deployment_vpc = var.vpcs_range_to_peer_to_deployment_vpc
  depends_on                           = [module.network]
}
