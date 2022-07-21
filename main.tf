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
  nics_number          = var.nics_number
  vpcs                 = var.vpcs
  prefix               = var.prefix
  region               = var.region
  subnets              = var.subnets
  subnets-cidr-range   = var.subnets-cidr-range
  set_peering          = var.set_peering
  zone                 = var.zone
  create_vpc_connector = var.create_vpc_connector
  vpc_connector_range  = var.vpc_connector_range
  vpc_connector_name   = var.vpc_connector_name
  private_network      = var.private_network
  sg_public_ssh_cidr_range = var.sg_public_ssh_cidr_range
  providers = {
    google = google.deployment
  }
  depends_on = [ module.create_service_account]
}


module "create_local_centos_repo" {
  count              = var.create_local_repo ? 1 : 0
  source             = "./modules/local_centos_repo"
  project            = var.project
  zone               = var.zone
  region             = var.region
  family_image       = "centos-7"
  project_image      = "centos-cloud"
  vpcs_peering       = module.setup_network.output-vpcs-names
  public_cidr_range  = var.repo_public_cidr_range
  private_cidr_range = var.repo_private_cidr_range
  vpc_range          = "10.0.0.0/24"

  providers = {
    google = google.main
  }

  depends_on = [module.setup_network]
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
  vpcs                   = module.setup_network.output-vpcs-names
  providers = {
    google = google.shared-vpc
  }

  depends_on = [module.create_service_account, module.setup_network ]
}


module "shared_vpc_peering" {
  count                  = var.create_shared_vpc ? 1 : 0
  source                 = "./modules/shared_vpcs"
  deploy_on_host_project = false
  service_project        = var.service_project
  prefix                 = var.prefix
  project                = var.project
  host_project           = var.host_project
  shared_vpcs            = var.shared_vpcs
  vpcs                   = module.setup_network.output-vpcs-names
  sa_email               = module.create_service_account.outputs-service-account-email
  providers = {
    google = google.deployment
  }
  depends_on = [module.host_vpc_peering, module.setup_network ]
}

module "create_weka_image" {
  count = var.create_weka_image ? 1 : 0
  source = "./modules/weka_image"
  project = var.project
  region = var.region
  zone = var.zone
  vpc_name = module.setup_network.output-vpcs-names[0]
  subnet_name = module.setup_network.output-subnetwork-name[0]
  machine_type = var.machine_type
  sa_email = module.create_service_account.outputs-service-account-email
  weka_image_name = var.weka_image_name
  weka_image_project = var.weka_image_project
  providers = {
    google = google.main
  }
  depends_on = [module.setup_network, module.create_service_account]
}

module "deploy_weka" {
  source               = "./modules/deploy_weka"
  cluster_name         = var.cluster_name
  project              = var.project
  nics_number          = var.nics_number
  vpcs                 = module.setup_network.output-vpcs-names
  prefix               = var.prefix
  region               = var.region
  subnets_name         = module.setup_network.output-subnetwork-name
  zone                 = var.zone
  cluster_size         = var.cluster_size
  get_weka_io_token    = var.get_weka_io_token
  install_url          = var.install_url
  machine_type         = var.machine_type
  weka_image_name      = var.create_weka_image ? module.create_weka_image[0].output-weka-image-name : var.weka_image_name
  weka_image_project   = var.create_weka_image ? module.create_weka_image[0].output-weka-image-project : var.weka_image_project
  nvmes_number         = var.nvmes_number
  username             = var.username
  private_network      = var.private_network
  weka_username        = var.weka_username
  weka_version         = var.weka_version
  bucket-location      = var.bucket-location
  vpc_connector        = module.setup_network.output-vpc-connector-name
  sa_email             = module.create_service_account.outputs-service-account-email
  yum_repo_server      = var.yum_repo_server
  create_cloudscheduler_sa = var.create_cloudscheduler_sa

  providers = {
    google = google.deployment
  }

  depends_on = [module.create_service_account, module.create_local_centos_repo, module.create_weka_image]
}
