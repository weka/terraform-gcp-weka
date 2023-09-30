provider "google" {
  project = var.project_id
  region  = var.region
}

module "weka_deployment" {
  source              = "../.."
  cluster_name        = "poc"
  project_id          = var.project_id
  prefix              = "weka"
  region              = var.region
  zone                = var.zone
  cluster_size        = 6
  nvmes_number        = 2
  get_weka_io_token   = var.get_weka_io_token
  set_obs_integration = true
  allow_ssh_ranges    = ["0.0.0.0/0"]
}

output "weka_deployment_output" {
  value = module.weka_deployment
}
