resource "time_sleep" "wait_120_seconds" {
  create_duration = "120s"
  depends_on      = [google_cloudfunctions2_function.cloud_internal_function]
}

module "nfs_protocol_gateways" {
  count                        = var.nfs_protocol_gateways_number > 0 ? 1 : 0
  source                       = "./modules/protocol_gateways"
  subnets_list                 = local.subnets_name
  zone                         = var.zone
  project_id                   = var.project_id
  region                       = var.region
  source_image_id              = var.source_image_id
  gateways_number              = var.nfs_protocol_gateways_number
  gateways_name                = "${var.prefix}-${var.cluster_name}-nfs-protocol-gateway"
  protocol                     = "NFS"
  secondary_ips_per_nic        = var.nfs_protocol_gateway_secondary_ips_per_nic
  backend_lb_ip                = google_compute_forwarding_rule.google_compute_forwarding_rule.ip_address
  install_weka_url             = local.install_weka_url
  machine_type                 = var.nfs_protocol_gateway_machine_type
  yum_repo_server              = var.yum_repo_server
  sa_email                     = local.sa_email
  assign_public_ip             = var.assign_public_ip
  disk_size                    = var.nfs_protocol_gateway_disk_size
  frontend_container_cores_num = var.nfs_protocol_gateway_fe_cores_num
  weka_token_id                = var.get_weka_io_token != "" ? google_secret_manager_secret.secret_token[0].id : var.get_weka_io_token
  weka_password_id             = google_secret_manager_secret.secret_weka_password.id
  proxy_url                    = var.proxy_url
  setup_protocol               = var.nfs_setup_protocol
  network_project_id           = var.network_project_id
  vm_username                  = var.vm_username
  ssh_public_key               = local.ssh_public_key
  depends_on                   = [module.network, module.vpc_peering, time_sleep.wait_120_seconds, google_compute_forwarding_rule.google_compute_forwarding_rule, google_secret_manager_secret.secret_token, google_cloudfunctions2_function.cloud_internal_function]
}


module "smb_protocol_gateways" {
  count                        = var.smb_protocol_gateways_number > 0 ? 1 : 0
  source                       = "./modules/protocol_gateways"
  subnets_list                 = local.subnets_name
  zone                         = var.zone
  project_id                   = var.project_id
  region                       = var.region
  source_image_id              = var.source_image_id
  gateways_number              = var.smb_protocol_gateways_number
  gateways_name                = "${var.prefix}-${var.cluster_name}-smb-protocol-gateway"
  protocol                     = "SMB"
  setup_protocol               = var.smb_setup_protocol
  secondary_ips_per_nic        = var.smb_protocol_gateway_secondary_ips_per_nic
  backend_lb_ip                = google_compute_forwarding_rule.google_compute_forwarding_rule.ip_address
  install_weka_url             = local.install_weka_url
  machine_type                 = var.smb_protocol_gateway_machine_type
  yum_repo_server              = var.yum_repo_server
  sa_email                     = local.sa_email
  assign_public_ip             = var.assign_public_ip
  disk_size                    = var.smb_protocol_gateway_disk_size
  frontend_container_cores_num = var.smb_protocol_gateway_fe_cores_num
  weka_token_id                = var.get_weka_io_token != "" ? google_secret_manager_secret.secret_token[0].id : var.get_weka_io_token
  weka_password_id             = google_secret_manager_secret.secret_weka_password.id
  proxy_url                    = var.proxy_url
  smb_cluster_name             = var.smb_cluster_name != "" ? var.smb_cluster_name : "${var.prefix}-${var.cluster_name}"
  smb_domain_name              = var.smb_domain_name
  smb_share_name               = var.smb_share_name
  smbw_enabled                 = var.smbw_enabled
  network_project_id           = var.network_project_id
  vm_username                  = var.vm_username
  ssh_public_key               = local.ssh_public_key
  depends_on                   = [module.network, module.vpc_peering, time_sleep.wait_120_seconds, google_compute_forwarding_rule.google_compute_forwarding_rule, google_secret_manager_secret.secret_token, google_cloudfunctions2_function.cloud_internal_function]
}
