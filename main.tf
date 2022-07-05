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
  cluster_name         = var.cluster_name
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
  providers = {
    google = google.deployment
  }
  depends_on = [ module.create_service_account]
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
  subnets_range        = module.setup_network.output-subnets-range
  private_key_filename = var.private_key_filename
  zone                 = var.zone
  cluster_size         = var.cluster_size
  gateway_address_list = module.setup_network.output-gateway-address
  get_weka_io_token    = var.get_weka_io_token
  machine_type         = var.machine_type
  nvmes_number         = var.nvmes_number
  username             = var.username
  weka_username        = var.weka_username
  weka_version         = var.weka_version
  bucket-location      = var.bucket-location
  subnets              = var.subnets
  vpc-connector        = module.setup_network.output-vpc-connector-name
  sa_email             = module.create_service_account.outputs-service-account-email

  providers = {
    google = google.deployment
  }

  depends_on = [module.create_service_account]
}