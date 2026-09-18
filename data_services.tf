module "data_services" {
  count                        = var.data_services_number > 0 ? 1 : 0
  source                       = "./modules/data_services"
  subnets_list                 = local.subnets_name
  zone                         = var.zone
  project_id                   = var.project_id
  region                       = var.region
  source_image_id              = var.source_image_id
  data_services_number         = var.data_services_number
  data_services_name           = "${var.prefix}-${var.cluster_name}-data-services"
  machine_type                 = var.data_services_instance_type
  yum_repository_appstream_url = var.yum_repository_appstream_url
  yum_repository_baseos_url    = var.yum_repository_baseos_url
  sa_email                     = local.sa_email
  assign_public_ip             = local.assign_public_ip
  weka_volume_size             = var.data_services_weka_volume_size
  root_volume_size             = var.data_services_root_volume_size
  proxy_url                    = var.proxy_url
  network_project_id           = var.network_project_id
  vm_username                  = var.vm_username
  ssh_public_key               = local.ssh_public_key
  deploy_function_url          = format("%s%s", local.internal_function_uri, "?action=deploy")
  report_function_url          = format("%s%s", local.internal_function_uri, "?action=report")
  labels_map                   = var.labels_map
  depends_on                   = [module.network, module.peering, module.shared_vpc_peering, time_sleep.wait_120_seconds, google_compute_forwarding_rule.google_compute_forwarding_rule, google_secret_manager_secret.secret_token, google_cloudfunctions2_function.cloud_internal_function, google_cloud_run_v2_service.cloud_internal]
}
