module "create_service_account" {
  source = "./modules/service_account"
  project = var.project
  prefix = var.prefix
  sa_name = var.sa_name
  providers = {
    google = google.main
  }
}


module "setup_network" {
  source               = "./modules/setup_network"
  project              = var.project
  vpc_number           = var.vpc_number
  vpcs_list            = var.vpcs_list
  prefix               = var.prefix
  region               = var.region
  subnets              = var.subnets
  subnets-cidr-range   = var.subnets-cidr-range
  set_peering          = var.set_peering
  zone                 = var.zone
  create_vpc_connector = var.create_vpc_connector
  vpc_connector_range  = var.vpc_connector_range
  vpc_connector_name   = var.vpc_connector_name
  providers = {
    google = google.deployment
  }
  depends_on = [ module.create_service_account]
}


module "host_vpc_peering" {
  count                  = var.create_shared_vpc ? 1 : 0
  source                 = "./modules/shared_vpcs"
  deploy_on_host_project = true
  service_project        = var.service_project
  prefix                 = var.prefix
  project                = var.host_project
  host_project           = var.host_project
  shared_vpcs            = var.shared_vpcs
  vpcs_list              = module.setup_network.output-vpcs-names
  sa_email               = module.create_service_account.outputs-service-account-email
  providers = {
    google = google.shared-vpc
  }

  depends_on = [module.create_service_account, module.setup_network ]
}

module "deploy_weka" {
  source                   = "./modules/deploy_weka"
  cluster_name             = var.cluster_name
  project                  = var.project
  project_number           = var.project_number
  nics_number              = var.nics_number
  vpcs_list                = module.setup_network.output-vpcs-names
  prefix                   = var.prefix
  region                   = var.region
  subnets_list             = module.setup_network.output-subnetwork-name
  zone                     = var.zone
  cluster_size             = var.cluster_size
  install_url              = var.install_url
  machine_type             = var.machine_type
  nvmes_number             = var.nvmes_number
  username                 = var.username
  weka_username            = var.weka_username
  weka_version             = var.weka_version
  bucket_location          = var.bucket_location
  vpc_connector            = module.setup_network.output-vpc-connector-name
  sa_email                 = module.create_service_account.outputs-service-account-email
  create_cloudscheduler_sa = var.create_cloudscheduler_sa
  yum_repo_server      = var.yum_repo_server

  providers = {
    google = google.deployment
  }

  depends_on = [module.create_service_account]
}