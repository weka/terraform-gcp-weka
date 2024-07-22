provider "google" {
  project = var.project_id
  region  = var.region
}

module "weka_deployment" {
  source                               = "../.."
  cluster_name                         = "poc"
  prefix                               = "weka"
  project_id                           = var.project_id
  region                               = var.region
  weka_tar_bucket_name                 = "weka-installation"
  zone                                 = var.zone
  cluster_size                         = 6
  yum_repo_server                      = "http://10.26.2.7"
  vpcs_to_peer_to_deployment_vpc       = ["weka-global-test-tf-vars-vpc"]
  vpcs_range_to_peer_to_deployment_vpc = ["10.26.2.0/24"]
  tiering_enable_obs_integration       = true
  assign_public_ip                     = false
  create_worker_pool                   = true
  weka_tar_project_id                  = "wekaio-rnd"
  install_weka_url                     = "gs://weka-installation/weka-4.2.11.tar"
  create_nat_gateway                   = false
}
