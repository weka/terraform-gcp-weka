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
  zone                           = "europe-west1-b"
  cluster_size                   = 6
  install_weka_url               = "gs://weka-installation/weka-4.2.5.tar"
  yum_repo_server                = "http://10.26.2.2/base/Packages/"
  tiering_enable_obs_integration = true
  create_worker_pool             = true
  assign_public_ip               = false
}
