module "clients" {
  count                        = var.clients_number > 0 ? 1 : 0
  source                       = "./modules/clients"
  clients_number               = var.clients_number
  clients_use_dpdk             = var.clients_use_dpdk
  yum_repository_appstream_url = var.yum_repository_appstream_url
  yum_repository_baseos_url    = var.yum_repository_baseos_url
  clients_name                 = "${var.prefix}-${var.cluster_name}-client"
  frontend_container_cores_num = var.clients_use_dpdk ? var.client_frontend_cores : 1
  machine_type                 = var.client_instance_type
  backend_lb_ip                = google_compute_forwarding_rule.google_compute_forwarding_rule.ip_address
  assign_public_ip             = local.assign_public_ip
  project_id                   = var.project_id
  region                       = var.region
  sa_email                     = local.sa_email
  source_image_id              = var.client_source_image_id
  subnets_list                 = local.subnets_name
  network_project_id           = var.network_project_id
  zone                         = var.zone
  vm_username                  = var.vm_username
  ssh_public_key               = local.ssh_public_key
  nic_type                     = var.client_nic_type
  custom_data                  = var.clients_custom_data
  labels_map                   = var.labels_map
  root_volume_size             = var.clients_root_volume_size
  depends_on = [
    google_compute_forwarding_rule.google_compute_forwarding_rule, google_workflows_workflow.scale_up,
    google_cloudfunctions2_function.cloud_internal_function, module.shared_vpc_peering, module.peering,
    google_cloud_run_v2_service.cloud_internal
  ]
}
