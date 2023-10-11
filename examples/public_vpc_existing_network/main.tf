provider "google" {
  project = var.project_id
  region  = var.region
}

module "weka_deployment" {
  source              = "../.."
  cluster_name        = "poc"
  prefix              = "weka"
  project_id          = var.project_id
  vpcs_name           = ["weka-vpc-0", "weka-vpc-1", "weka-vpc-2", "weka-vpc-3"]
  subnets_name        = ["weka-subnet-0", "weka-subnet-1", "weka-subnet-2", "weka-subnet-3"]
  region              = var.region
  zone                = "europe-west1-b"
  cluster_size        = 6
  nvmes_number        = 2
  get_weka_io_token   = var.get_weka_io_token
  private_dns_name    = "weka.private.net."
  private_zone_name   = "weka-private-zone"
  vpc_connector_name  = "weka-connector"
  set_obs_integration = true
  create_worker_pool  = false
}
