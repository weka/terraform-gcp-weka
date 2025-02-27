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
  yum_repository_appstream_url         = "https://europe-west1-yum.pkg.dev/remote/wekaio-rnd/appstream-rocky-8-10"
  yum_repository_baseos_url            = "https://europe-west1-yum.pkg.dev/remote/wekaio-rnd/baseos-rocky-8-10"
  vpcs_to_peer_to_deployment_vpc       = ["global-wekaio-rnd-vpc"]
  vpcs_range_to_peer_to_deployment_vpc = ["10.26.2.0/24"]
  tiering_enable_obs_integration       = true
  assign_public_ip                     = false
  create_worker_pool                   = true
  weka_tar_project_id                  = "wekaio-rnd"
  install_weka_url                     = "gs://weka-installation/weka-4.2.9.28.tar"
  create_nat_gateway                   = false
}
