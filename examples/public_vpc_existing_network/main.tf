provider "google" {
  project = var.project_id
  region  = var.region
}

module "weka_deployment" {
  source                         = "../.."
  cluster_name                   = "poc"
  prefix                         = "weka"
  project_id                     = var.project_id
  vpcs_name                      = ["weka-vpc"]
  subnets_name                   = ["weka-subnet"]
  region                         = var.region
  zone                           = "europe-west1-b"
  cluster_size                   = 6
  get_weka_io_token              = var.get_weka_io_token
  private_dns_name               = "weka.private.net."
  private_zone_name              = "weka-private-zone"
  vpc_connector_name             = "weka-connector"
  tiering_enable_obs_integration = true
  create_worker_pool             = false
  assign_public_ip               = true
}
