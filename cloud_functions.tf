# ======================== cloud function ============================
locals {
  function_zip_path       = "/tmp/${var.project_id}-${var.cluster_name}-cloud-functions.zip"
  worker_pool_id          = var.create_worker_pool ? module.worker_pool[0].worker_pool_id : var.worker_pool_id
  stripe_width_calculated = var.cluster_size - var.protection_level - 1
  stripe_width            = local.stripe_width_calculated < 16 ? local.stripe_width_calculated : 16
  get_compute_memory      = var.set_dedicated_fe_container ? var.containers_config_map[var.machine_type].memory[1] : var.containers_config_map[var.machine_type].memory[0]
  state_bucket            = var.state_bucket_name == "" ? google_storage_bucket.weka_deployment[0].name : var.state_bucket_name
  install_weka_url        = var.install_weka_url != "" ? var.install_weka_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"

  # common function for multiple actions
  cloud_internal_function_name = "${var.prefix}-${var.cluster_name}-weka-functions"
  function_ingress_settings    = var.subnet_autocreate_as_private ? "ALLOW_INTERNAL_ONLY" : "ALLOW_ALL"
  deployment_project_number    = data.google_project.project.number
}

data "archive_file" "function_zip" {
  type        = "zip"
  output_path = local.function_zip_path
  excludes    = ["${path.module}/cloud-functions/cloud_functions_test.go"]
  source_dir  = "${path.module}/cloud-functions/"
}

# ================== function zip =======================
resource "google_storage_bucket_object" "cloud_functions_zip" {
  name       = "${var.prefix}-${var.cluster_name}-cloud-functions.zip"
  bucket     = local.state_bucket
  source     = local.function_zip_path
  depends_on = [data.archive_file.function_zip, google_project_service.run_api, google_project_service.artifactregistry_api]
}


# ======================== deploy ============================
resource "google_cloudfunctions2_function" "cloud_internal_function" {
  name        = local.cloud_internal_function_name
  description = "deploy, fetch, resize, clusterize, clusterize finalization, join, join_finalization, terminate, transient, terminate_cluster, scale_up functions"
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
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    vpc_connector                  = local.vpc_connector_id
    ingress_settings               = local.function_ingress_settings
    vpc_connector_egress_settings  = "PRIVATE_RANGES_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT : var.project_id
      ZONE : var.zone
      REGION : var.region
      CLOUD_FUNCTION_NAME : local.cloud_internal_function_name
      INSTANCE_GROUP : google_compute_instance_group.this.name
      GATEWAYS : join(",", [for s in data.google_compute_subnetwork.this : s.gateway_address])
      SUBNETS : format("(%s)", join(" ", [for s in data.google_compute_subnetwork.this : s.ip_cidr_range]))
      USER_NAME_ID : google_secret_manager_secret_version.user_secret_key.id
      PASSWORD_ID : google_secret_manager_secret_version.password_secret_key.id
      TOKEN_ID : var.get_weka_io_token == "" ? "" : google_secret_manager_secret_version.token_secret_key[0].id
      BUCKET : local.state_bucket
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
    }
  }
  depends_on = [module.network, module.worker_pool, module.shared_vpc_peering, module.peering, google_project_service.project_function_api, google_project_service.run_api, google_project_service.artifactregistry_api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "cloud_internal_invoker" {
  location       = google_cloudfunctions2_function.cloud_internal_function.location
  cloud_function = google_cloudfunctions2_function.cloud_internal_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
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
    vpc_connector_egress_settings  = "PRIVATE_RANGES_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
  }
  depends_on = [module.network, module.worker_pool, module.shared_vpc_peering, google_project_service.project_function_api, google_project_service.run_api, google_project_service.artifactregistry_api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "weka_internal_invoker" {
  location       = google_cloudfunctions2_function.scale_down_function.location
  cloud_function = google_cloudfunctions2_function.scale_down_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
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
    vpc_connector_egress_settings  = "PRIVATE_RANGES_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT : var.project_id
      ZONE : var.zone
      BUCKET : local.state_bucket
      INSTANCE_GROUP : google_compute_instance_group.this.name
      USER_NAME_ID : google_secret_manager_secret_version.user_secret_key.id
      PASSWORD_ID : google_secret_manager_secret_version.password_secret_key.id
    }
  }
  depends_on = [module.network, module.worker_pool, module.shared_vpc_peering, google_project_service.project_function_api, google_project_service.run_api, google_project_service.artifactregistry_api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "status_invoker" {
  location       = google_cloudfunctions2_function.status_function.location
  cloud_function = google_cloudfunctions2_function.status_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}
