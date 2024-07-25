provider "google" {
  project = var.project_id
  region  = var.region
}



module "weka_deployment" {
  source                               = "../.."
  cluster_name                         = "poc"
  prefix                               = "weka"
  zone                                 = var.zone
  cluster_size                         = 6
  install_weka_url                     = "gs://weka-installation/weka-4.2.12.87.tar"
  weka_tar_bucket_name                 = "weka-installation"
  yum_repo_server                      = "http://10.26.2.7"
  vpcs_to_peer_to_deployment_vpc       = ["repo-global-test-tf-vars-vpc"]
  vpcs_range_to_peer_to_deployment_vpc = ["10.26.2.0/24"]
  weka_tar_project_id                  = "wekaio-rnd"
  tiering_enable_obs_integration       = true
  create_worker_pool                   = true
  assign_public_ip                     = false
  subnet_autocreate_as_private         = true
  create_nat_gateway                   = true
  endpoint_apis_internal_ip_address    = "10.0.1.2"
  endpoint_vpcsc_internal_ip_address   = "10.0.1.3"
  psc_subnet_cidr                      = "10.9.0.0/28"
  project_id                           = var.project_id
  region                               = var.region
}
