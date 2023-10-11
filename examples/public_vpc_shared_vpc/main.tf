provider "google" {
  project = var.project_id
  region  = var.region
}


module "weka_deployment" {
  source              = "../.."
  prefix              = "weka"
  cluster_name        = "poc"
  project_id          = var.project_id
  region              = var.region
  zone                = "europe-west1-b"
  allow_ssh_ranges    = ["0.0.0.0/0"]
  cluster_size        = 6
  nvmes_number        = 2
  get_weka_io_token   = var.get_weka_io_token
  set_obs_integration = true
  shared_vpcs         = ["..",".."]
  host_project        = var.host_project
  host_shared_range   = [".."]
}