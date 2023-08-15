module "clients" {
  count              = var.clients_number > 0 ? 1 : 0
  source             = "./modules/clients"
  clients_number     = var.clients_number
  mount_clients_dpdk = var.mount_clients_dpdk
  yum_repo_server    = var.yum_repo_server
  clients_name       = "${var.prefix}-${var.cluster_name}-client"
  nics_numbers       = var.mount_clients_dpdk ? var.client_nics_num : 1
  machine_type       = var.client_instance_type
  backend_lb_ip      = google_compute_forwarding_rule.google_compute_forwarding_rule.ip_address
  assign_public_ip   = var.assign_public_ip
  disk_size          = var.default_disk_size + var.tiering_ssd_percent * var.container_number_map[var.machine_type].frontend
  cluster_name       = var.cluster_name
  prefix             = var.prefix
  project_id         = var.project_id
  region             = var.region
  sa_email           = var.sa_email
  source_image       = var.weka_image_id
  subnets_list       = var.subnets_name
  zone               = var.zone
  depends_on         = [google_compute_forwarding_rule.google_compute_forwarding_rule,google_workflows_workflow.scale_up, google_cloudfunctions2_function.cloud_internal_function]
}