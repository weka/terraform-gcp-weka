resource "time_sleep" "wait_120_seconds" {
  create_duration = "120s"
  depends_on      = [google_cloudfunctions2_function.cloud_internal_function]
}

module "protocol_gateways" {
  count                 = var.protocol_gateways_number > 0 ? 1 : 0
  source                = "./modules/protocol_gateways"
  subnets_list          = var.subnets_name
  zone                  = var.zone
  cluster_name          = var.cluster_name
  project_id            = var.project_id
  region                = var.region
  source_image_id       = var.source_image_id
  gateways_number       = var.protocol_gateways_number
  gateways_name         = "${var.prefix}-${var.cluster_name}-protocol-gateway"
  protocol              = var.protocol
  nics_numbers          = var.protocol_gateway_nics_num
  secondary_ips_per_nic = var.protocol_gateway_secondary_ips_per_nic
  backend_lb_ip         = google_compute_forwarding_rule.google_compute_forwarding_rule.ip_address
  install_weka_url      = var.install_weka_url != "" ? var.install_weka_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"
  machine_type          = var.protocol_gateway_machine_type
  yum_repo_server       = var.yum_repo_server
  sa_email              = var.sa_email
  vm_username           = var.weka_username
  assign_public_ip      = var.assign_public_ip
  disk_size             = var.protocol_gateway_disk_size
  frontend_num          = var.protocol_gateway_frontend_num
  weka_token_id         = google_secret_manager_secret.secret_token[0].id
  weka_password_id      = google_secret_manager_secret.secret_weka_password.id
  proxy_url             = var.proxy_url
  depends_on            = [time_sleep.wait_120_seconds, google_compute_forwarding_rule.google_compute_forwarding_rule, google_secret_manager_secret.secret_token,google_cloudfunctions2_function.cloud_internal_function]
}