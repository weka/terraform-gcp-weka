provider "google" {
  project = var.project_id
  region  = var.region
}

module "weka_deployment" {
  source                         = "../.."
  cluster_name                   = "poc"
  project_id                     = var.project_id
  prefix                         = "weka"
  region                         = var.region
  zone                           = "europe-west1-b"
  cluster_size                   = 6
  get_weka_io_token              = var.get_weka_io_token
  tiering_enable_obs_integration = true
  create_worker_pool             = true
  allow_ssh_cidrs                = ["0.0.0.0/0"]
  assign_public_ip               = true
}
