provider "google" {
  project = var.project_id
  region  = var.region
}


module "weka_deployment" {
  source                         = "../.."
  prefix                         = "weka"
  cluster_name                   = "poc"
  project_id                     = var.project_id
  region                         = var.region
  zone                           = "europe-west1-b"
  allow_ssh_cidrs                = ["0.0.0.0/0"]
  cluster_size                   = 6
  get_weka_io_token              = var.get_weka_io_token
  tiering_enable_obs_integration = true
  shared_vpcs                    = ["..", ".."]
  host_project                   = var.host_project
  host_shared_range              = [".."]
  shared_vpc_project_id          = var.shared_vpc_project_id
  enable_shared_vpc_host_project = true
  set_shared_vpc_peering         = true
}
