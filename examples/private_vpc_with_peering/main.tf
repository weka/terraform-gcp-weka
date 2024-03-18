provider "google" {
  project = var.project_id
  region  = var.region
}

module "weka_deployment" {
  source                         = "../.."
  cluster_name                   = "poc"
  prefix                         = "weka"
  project_id                     = var.project_id
  region                         = var.region
  weka_tar_bucket_name           = "weka-installation"
  zone                           = var.zone
  cluster_size                   = 6
  install_weka_url               = "gs://weka-installation/weka-4.2.9.28.tar"
  yum_repo_server                = "http://10.26.2.2"
  tiering_enable_obs_integration = true
  assign_public_ip               = false
  create_worker_pool             = true
  vpcs_to_peer_to_deployment_vpc = ["repo-global-vpc"]
  weka_tar_project_id            = "wekaio-rnd"
}
