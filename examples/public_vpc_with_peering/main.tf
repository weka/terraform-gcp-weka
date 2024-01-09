provider "google" {
  project = var.project_id
  region  = var.region
}


module "weka_deployment" {
  source                               = "../.."
  prefix                               = "weka"
  cluster_name                         = "poc"
  project_id                           = var.project_id
  region                               = var.region
  zone                                 = "europe-west1-b"
  allow_ssh_cidrs                      = ["0.0.0.0/0"]
  cluster_size                         = 6
  get_weka_io_token                    = var.get_weka_io_token
  tiering_enable_obs_integration       = true
  vpc_to_peer_project_id               = var.vpc_to_peer_project_id
  vpcs_range_to_peer_to_deployment_vpc = [".."]
  vpcs_to_peer_to_deployment_vpc       = [".."]
}
