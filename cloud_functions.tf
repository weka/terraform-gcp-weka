data "google_client_openid_userinfo" "user" {
}

# ======================== cloud function ============================
locals {
  function_zip_path       = "/tmp/${var.project_id}-${var.cluster_name}-cloud-functions.zip"
  worker_pool_id          = var.create_worker_pool ? module.worker_pool[0].worker_pool_id : var.worker_pool_id
  stripe_width_calculated = var.cluster_size - var.protection_level - 1
  stripe_width            = local.stripe_width_calculated < 16 ? local.stripe_width_calculated : 16
  get_compute_memory      = var.set_dedicated_fe_container ? var.containers_config_map[var.machine_type].memory[1] : var.containers_config_map[var.machine_type].memory[0]
  state_bucket            = var.state_bucket_name == "" ? google_storage_bucket.weka_deployment[0].name : var.state_bucket_name
  install_weka_url        = var.install_weka_url != "" ? var.install_weka_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"
  gateways_name           = "${var.prefix}-${var.cluster_name}-nfs-protocol-gateway"

  # common function for multiple actions
  cloud_internal_function_name = "${var.prefix}-${var.cluster_name}-weka-functions"
  function_ingress_settings    = var.subnet_autocreate_as_private ? "ALLOW_INTERNAL_ONLY" : "ALLOW_ALL"
  deployment_project_number    = data.google_project.project.number

  user_email                             = data.google_client_openid_userinfo.user.email
  domain_name                            = split("@", local.user_email)[1]
  cloud_function_invoker_allowed_members = endswith(local.user_email, "gserviceaccount.com") ? concat(["serviceAccount:${local.user_email}", "serviceAccount:${local.sa_email}"]) : concat(["domain:${local.domain_name}", "serviceAccount:${local.sa_email}"])
}

data "archive_file" "function_zip" {
  type        = "zip"
  output_path = local.function_zip_path
  excludes    = ["${path.module}/cloud-functions/cloud_functions_test.go"]
  source_dir  = "${path.module}/cloud-functions/"
}

# ================== function zip =======================
resource "google_storage_bucket_object" "cloud_functions_zip" {
  name       = "${var.prefix}-${var.cluster_name}-cloud-functions-${filemd5(local.function_zip_path)}.zip"
  bucket     = local.state_bucket
  source     = local.function_zip_path
  depends_on = [data.archive_file.function_zip, google_project_service.run_api, google_project_service.artifactregistry_api]
}


# ======================== deploy ============================
resource "google_cloudfunctions2_function" "cloud_internal_function" {
  name        = local.cloud_internal_function_name
  description = "deploy, fetch, resize, clusterize, clusterize finalization, join, join_finalization, join_nfs_finalization, terminate, transient, terminate_cluster, scale_up functions"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime     = "go122"
    entry_point = "CloudInternal"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = local.state_bucket
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 20
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    vpc_connector                  = local.vpc_connector_id
    ingress_settings               = local.function_ingress_settings
    vpc_connector_egress_settings  = var.vpc_connector_egress_settings
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT : var.project_id
      ZONE : var.zone
      REGION : var.region
      CLOUD_FUNCTION_NAME : local.cloud_internal_function_name
      INSTANCE_GROUP : google_compute_instance_group.this.name
      NFS_INSTANCE_GROUP : var.nfs_setup_protocol ? google_compute_instance_group.nfs[0].name : ""
      GATEWAYS : join(",", [for s in data.google_compute_subnetwork.this : s.gateway_address])
      SUBNETS : format("(%s)", join(" ", [for s in data.google_compute_subnetwork.this : s.ip_cidr_range]))
      USER_NAME_ID : google_secret_manager_secret.secret_weka_username.id
      ADMIN_PASSWORD_ID = google_secret_manager_secret.secret_weka_password.id
      DEPLOYMENT_PASSWORD_ID : google_secret_manager_secret.weka_deployment_password.id
      TOKEN_ID : var.get_weka_io_token == "" ? "" : google_secret_manager_secret.secret_token[0].id
      BUCKET : local.state_bucket
      STATE_OBJ_NAME : local.state_object_name
      INSTALL_URL : local.install_weka_url
      # Configuration for google_cloudfunctions2_function.cloud_internal_function may not refer to itself.
      # REPORT_URL : format("%s%s", google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri, "?action=report")
      NICS_NUM : local.nics_number
      COMPUTE_MEMORY : local.get_compute_memory
      DRIVE_CONTAINER_CORES_NUM : var.containers_config_map[var.machine_type].drive
      COMPUTE_CONTAINER_CORES_NUM : var.set_dedicated_fe_container ? var.containers_config_map[var.machine_type].compute : var.containers_config_map[var.machine_type].compute + 1
      FRONTEND_CONTAINER_CORES_NUM : var.set_dedicated_fe_container ? var.containers_config_map[var.machine_type].frontend : 0
      NVMES_NUM : var.nvmes_number
      HOSTS_NUM : var.cluster_size
      NICS_NUM : local.nics_number
      CLUSTER_NAME : var.cluster_name
      PREFIX : var.prefix
      INSTALL_DPDK : var.install_cluster_dpdk
      PROTECTION_LEVEL : var.protection_level
      STRIPE_WIDTH : var.stripe_width != -1 ? var.stripe_width : local.stripe_width
      HOTSPARE : var.hotspare
      SET_OBS : var.tiering_enable_obs_integration
      OBS_NAME : var.tiering_obs_name == "" ? "" : var.tiering_obs_name
      OBS_TIERING_SSD_PERCENT : var.tiering_enable_ssd_percent
      TIERING_TARGET_SSD_RETENTION : var.tiering_obs_target_ssd_retention
      TIERING_START_DEMOTE : var.tiering_obs_start_demote
      DISK_NAME : var.default_disk_name
      # for terminate
      LOAD_BALANCER_NAME : google_compute_region_backend_service.backend_service.name
      # for scale_up
      YUM_REPO_SERVER : var.yum_repo_server
      BACKEND_TEMPLATE : google_compute_instance_template.this.id
      # SMBW
      CREATE_CONFIG_FS : (var.smbw_enabled && var.smb_setup_protocol) || var.s3_setup_protocol
      # Weka proxy url
      PROXY_URL : var.proxy_url
      WEKA_HOME_URL : var.weka_home_url
      DOWN_BACKENDS_REMOVAL_TIMEOUT : var.debug_down_backends_removal_timeout
      BACKEND_LB_IP : google_compute_forwarding_rule.google_compute_forwarding_rule.ip_address
      TRACES_PER_FRONTEND : var.traces_per_ionode
      # NFS vars
      NFS_GATEWAYS_NAME : var.nfs_setup_protocol ? local.gateways_name : ""
      NFS_STATE_OBJ_NAME : var.nfs_setup_protocol ? local.nfs_state_object_name : ""
      NFS_GATEWAYS_TEMPLATE_NAME : var.nfs_setup_protocol ? local.gateways_name : ""
      NFS_INTERFACE_GROUP_NAME : var.nfs_interface_group_name
      NFS_SECONDARY_IPS_NUM : var.nfs_protocol_gateway_secondary_ips_per_nic
      NFS_PROTOCOL_GATEWAY_FE_CORES_NUM : var.nfs_protocol_gateway_fe_cores_num
      NFS_PROTOCOL_GATEWAYS_NUM : var.nfs_protocol_gateways_number
      NFS_DISK_SIZE : var.nfs_protocol_gateway_disk_size
      SMB_DISK_SIZE                     = var.smb_protocol_gateway_disk_size
      S3_DISK_SIZE                      = var.s3_protocol_gateway_disk_size
      SMB_PROTOCOL_GATEWAY_FE_CORES_NUM = var.smb_protocol_gateway_fe_cores_num
      S3_PROTOCOL_GATEWAY_FE_CORES_NUM  = var.s3_protocol_gateway_fe_cores_num
    }
  }
  lifecycle {
    precondition {
      condition     = var.install_weka_url != "" || var.weka_version != ""
      error_message = "Please provide either 'install_weka_url' or 'weka_version' variables."
    }
  }
  depends_on = [module.network, module.worker_pool, module.shared_vpc_peering, module.peering, google_project_service.project_function_api, google_project_service.run_api, google_project_service.artifactregistry_api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "cloud_internal_invoker" {
  count          = length(local.cloud_function_invoker_allowed_members)
  location       = google_cloudfunctions2_function.cloud_internal_function.location
  cloud_function = google_cloudfunctions2_function.cloud_internal_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = local.cloud_function_invoker_allowed_members[count.index]
}

# ======================== scale_down ============================
resource "google_cloudfunctions2_function" "scale_down_function" {
  name        = "${var.prefix}-${var.cluster_name}-scale-down"
  description = "scale cluster down"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime     = "go122"
    entry_point = "ScaleDown"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = local.state_bucket
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    vpc_connector                  = local.vpc_connector_id
    ingress_settings               = local.function_ingress_settings
    vpc_connector_egress_settings  = var.vpc_connector_egress_settings
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
  }
  depends_on = [module.network, module.worker_pool, module.shared_vpc_peering, google_project_service.project_function_api, google_project_service.run_api, google_project_service.artifactregistry_api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "weka_internal_invoker" {
  count          = length(local.cloud_function_invoker_allowed_members)
  location       = google_cloudfunctions2_function.cloud_internal_function.location
  cloud_function = google_cloudfunctions2_function.cloud_internal_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = local.cloud_function_invoker_allowed_members[count.index]
}

# ======================== status ============================
resource "google_cloudfunctions2_function" "status_function" {
  name        = "${var.prefix}-${var.cluster_name}-status"
  description = "get cluster status"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime     = "go122"
    entry_point = "Status"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = local.state_bucket
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }

  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    vpc_connector                  = local.vpc_connector_id
    ingress_settings               = local.function_ingress_settings
    vpc_connector_egress_settings  = var.vpc_connector_egress_settings
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT : var.project_id
      ZONE : var.zone
      BUCKET : local.state_bucket
      STATE_OBJ_NAME : local.state_object_name
      NFS_STATE_OBJ_NAME : var.nfs_setup_protocol ? local.nfs_state_object_name : ""
      INSTANCE_GROUP : google_compute_instance_group.this.name
      NFS_INSTANCE_GROUP : var.nfs_setup_protocol ? google_compute_instance_group.nfs[0].name : ""
      USER_NAME_ID : google_secret_manager_secret.secret_weka_username.id
      ADMIN_PASSWORD_ID : google_secret_manager_secret.secret_weka_password.id
      DEPLOYMENT_PASSWORD_ID : google_secret_manager_secret.weka_deployment_password.id
    }
  }
  depends_on = [module.network, module.worker_pool, module.shared_vpc_peering, google_project_service.project_function_api, google_project_service.run_api, google_project_service.artifactregistry_api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "status_invoker" {
  count          = length(local.cloud_function_invoker_allowed_members)
  location       = google_cloudfunctions2_function.status_function.location
  cloud_function = google_cloudfunctions2_function.status_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = local.cloud_function_invoker_allowed_members[count.index]
}
