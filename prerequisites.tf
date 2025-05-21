module "service_account" {
  count                       = var.sa_email == "" ? 1 : 0
  source                      = "./modules/service_account"
  project_id                  = var.project_id
  prefix                      = var.prefix
  cluster_name                = var.cluster_name
  tiering_obs_name            = var.tiering_obs_name
  state_bucket_name           = var.state_bucket_name
  weka_tar_bucket_name        = var.weka_tar_bucket_name
  weka_tar_project_id         = var.weka_tar_project_id
  network_project_id          = var.network_project_id
  allow_artifactregistry_role = var.yum_repository_appstream_url != "" || var.yum_repository_baseos_url != "" ? true : false
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
  sg_custom_ingress_rules            = var.sg_custom_ingress_rules
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
  labels_map                         = var.labels_map
  depends_on                         = [module.service_account]
}

locals {
  sa_email            = var.sa_email == "" ? module.service_account[0].service_account_email : var.sa_email
  subnets_name        = length(var.subnets_name) == 0 ? module.network[0].subnetwork_name : var.subnets_name
  private_zone_name   = var.private_zone_name == "" ? module.network[0].private_zone_name : var.private_zone_name
  private_dns_name    = var.private_dns_name == "" ? module.network[0].private_dns_name : var.private_dns_name
  vpcs_name           = length(var.vpcs_name) == 0 ? module.network[0].vpcs_names : var.vpcs_name
  network_project_id  = var.network_project_id != "" ? var.network_project_id : var.project_id
  vpc_connector_id    = var.vpc_connector_id == "" ? module.network[0].vpc_connector_id : var.vpc_connector_id
  dns_zone_project_id = var.dns_zone_project_id != "" ? var.dns_zone_project_id : local.network_project_id
  assign_public_ip    = var.assign_public_ip != "auto" ? var.assign_public_ip : length(var.subnets_name) == 0
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
  region     = var.region
  name       = local.subnets_name[count.index]
  depends_on = [module.network]
}

module "peering" {
  count                                = length(var.vpcs_to_peer_to_deployment_vpc) > 0 ? 1 : 0
  source                               = "./modules/vpc_peering"
  vpcs_name                            = local.vpcs_name
  vpcs_to_peer_to_deployment_vpc       = var.vpcs_to_peer_to_deployment_vpc
  vpcs_range_to_peer_to_deployment_vpc = var.vpcs_range_to_peer_to_deployment_vpc
  network_project_id                   = local.network_project_id
  depends_on                           = [module.network]
}

module "shared_vpc_peering" {
  count                          = var.host_project == "" ? 0 : 1
  source                         = "./modules/shared_vpcs"
  project_id                     = local.network_project_id
  prefix                         = var.prefix
  shared_vpc_project_id          = var.shared_vpc_project_id
  host_project                   = var.host_project
  shared_vpcs                    = var.shared_vpcs
  vpcs_name                      = local.vpcs_name
  set_shared_vpc_peering         = var.set_shared_vpc_peering
  host_shared_range              = var.host_shared_range
  enable_shared_vpc_host_project = var.enable_shared_vpc_host_project
  depends_on                     = [module.network]
}


resource "google_artifact_registry_repository_iam_member" "repo_appstream" {
  count      = var.yum_repository_appstream_url != "" ? 1 : 0
  location   = var.region
  repository = split("/", var.yum_repository_appstream_url)[length(split("/", var.yum_repository_appstream_url)) - 1]
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${local.sa_email}"
}

resource "google_artifact_registry_repository_iam_member" "repo_baseos" {
  count      = var.yum_repository_baseos_url != "" ? 1 : 0
  location   = var.region
  repository = split("/", var.yum_repository_baseos_url)[length(split("/", var.yum_repository_baseos_url)) - 1]
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${local.sa_email}"
}
