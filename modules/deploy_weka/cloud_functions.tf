# ======================== cloud function ============================

locals {
  function_zip_path = "/tmp/${var.project}-${var.cluster_name}-cloud-functions.zip"
  worker_pool_id = var.worker_pool_name != "" ? "projects/${var.project}/locations/${var.region}/workerPools/${var.worker_pool_name}" : var.worker_pool_name
  sa_email = var.sa_email
}

data "archive_file" "function_zip" {
  type        = "zip"
  output_path = local.function_zip_path
  excludes    = [ "${path.module}/cloud-functions/cloud_functions_test.go" ]
  source_dir = "${path.module}/cloud-functions/"
}

# ================== function zip =======================
resource "google_storage_bucket_object" "cloud_functions_zip" {
  name   = "${var.prefix}-${var.cluster_name}-cloud-functions.zip"
  bucket = google_storage_bucket.weka_deployment.name
  source = local.function_zip_path
  depends_on = [data.archive_file.function_zip, google_project_service.run-api, google_project_service.artifactregistry-api]
}


# ======================== deploy ============================
resource "google_cloudfunctions2_function" "deploy_function" {
  name        = "${var.prefix}-${var.cluster_name}-deploy"
  description = "deploy new instance"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime               = "go116"
    entry_point           = "Deploy"
    worker_pool           = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 60
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT : var.project
      ZONE : var.zone
      NICS_NUM : var.nics_number
      INSTANCE_GROUP : google_compute_instance_group.instance_group.name
      GATEWAYS : format("(%s)", join(" ", [for s in data.google_compute_subnetwork.subnets_list_ids : s.gateway_address] ))
      SUBNETS : format("(%s)", join(" ", [for s in data.google_compute_subnetwork.subnets_list_ids : s.ip_cidr_range] ))
      USER_NAME_ID : google_secret_manager_secret_version.user_secret_key.id
      PASSWORD_ID : google_secret_manager_secret_version.password_secret_key.id
      TOKEN_ID : var.private_network ? "" : google_secret_manager_secret_version.token_secret_key[0].id
      BUCKET : google_storage_bucket.weka_deployment.name
      INSTALL_URL : var.install_url != "" ? var.install_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"
      CLUSTERIZE_URL : google_cloudfunctions2_function.clusterize_function.service_config[0].uri
      JOIN_FINALIZATION_URL : google_cloudfunctions2_function.join_finalization_function.service_config[0].uri
    }
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "deploy_invoker" {
  project        = google_cloudfunctions2_function.deploy_function.project
  location       = google_cloudfunctions2_function.deploy_function.location
  cloud_function = google_cloudfunctions2_function.deploy_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}


resource "google_secret_manager_secret_iam_binding" "member-sa-username-secret" {
  project   = google_secret_manager_secret.secret_weka_username.project
  secret_id = google_secret_manager_secret.secret_weka_username.id
  role      = "roles/secretmanager.secretAccessor"
  members    = ["serviceAccount:${local.sa_email}"]
}


resource "google_secret_manager_secret_iam_binding" "member-sa-password-secret" {
  project   = google_secret_manager_secret.secret_weka_password.project
  secret_id = google_secret_manager_secret.secret_weka_password.id
  role      = "roles/secretmanager.secretAccessor"
  members   = ["serviceAccount:${local.sa_email}"]
}

# ======================== fetch ============================
resource "google_cloudfunctions2_function" "fetch_function" {
  name        = "${var.prefix}-${var.cluster_name}-fetch"
  description = "fetch cluster info"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime = "go116"
    entry_point = "Fetch"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 60
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT: var.project
      ZONE: var.zone
      INSTANCE_GROUP: google_compute_instance_group.instance_group.name
      BUCKET : google_storage_bucket.weka_deployment.name
      USER_NAME_ID: google_secret_manager_secret_version.user_secret_key.id
      PASSWORD_ID: google_secret_manager_secret_version.password_secret_key.id
    }
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "fetch_invoker" {
  project        = google_cloudfunctions2_function.fetch_function.project
  location       = google_cloudfunctions2_function.fetch_function.location
  cloud_function = google_cloudfunctions2_function.fetch_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== scale_down ============================
resource "google_cloudfunctions2_function" "scale_down_function" {
  name        = "${var.prefix}-${var.cluster_name}-scale-down"
  description = "scale cluster down"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime = "go116"
    entry_point = "ScaleDown"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    vpc_connector                  = var.vpc_connector
    ingress_settings               = "ALLOW_ALL"
    vpc_connector_egress_settings  = "PRIVATE_RANGES_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}
# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "scale_invoker" {
  project        = google_cloudfunctions2_function.scale_down_function.project
  location       = google_cloudfunctions2_function.scale_down_function.location
  cloud_function = google_cloudfunctions2_function.scale_down_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}
# ======================== scale_up ============================
resource "google_cloudfunctions2_function" "scale_up_function" {
  name        = "${var.prefix}-${var.cluster_name}-scale-up"
  description = "scale cluster up"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime = "go116"
    entry_point = "ScaleUp"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 60
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT: var.project
      ZONE: var.zone
      CLUSTER_NAME: var.cluster_name
      BACKEND_TEMPLATE: google_compute_instance_template.backends-template.id
      BUCKET : google_storage_bucket.weka_deployment.name
      INSTANCE_BASE_NAME: "${var.prefix}-${var.cluster_name}-vm"
    }
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "scale_up_invoker" {
  project        = google_cloudfunctions2_function.scale_up_function.project
  location       = google_cloudfunctions2_function.scale_up_function.location
  cloud_function = google_cloudfunctions2_function.scale_up_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}


# ======================== clusterize ============================
resource "google_cloudfunctions2_function" "clusterize_function" {
  name        = "${var.prefix}-${var.cluster_name}-clusterize"
  description = "return clusterize script"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime = "go116"
    entry_point = "Clusterize"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT: var.project
      ZONE: var.zone
      HOSTS_NUM: var.cluster_size
      NICS_NUM: var.nics_number
      GWS: format("(%s)", join(" ", [for s in data.google_compute_subnetwork.subnets_list_ids: s.gateway_address] ))
      CLUSTER_NAME: var.cluster_name
      NVMES_NUM: var.nvmes_number
      USER_NAME_ID: google_secret_manager_secret_version.user_secret_key.id
      PASSWORD_ID: google_secret_manager_secret_version.password_secret_key.id
      BUCKET: google_storage_bucket.weka_deployment.name
      CLUSTERIZE_FINALIZATION_URL: google_cloudfunctions2_function.clusterize_finalization_function.service_config[0].uri
    }
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "clusterize_invoker" {
  project        = google_cloudfunctions2_function.clusterize_function.project
  location       = google_cloudfunctions2_function.clusterize_function.location
  cloud_function = google_cloudfunctions2_function.clusterize_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== terminate ============================
resource "google_cloudfunctions2_function" "terminate_function" {
  name        = "${var.prefix}-${var.cluster_name}-terminate"
  description = "terminate instances"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime = "go116"
    entry_point = "Terminate"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT: var.project
      ZONE: var.zone
      INSTANCE_GROUP: google_compute_instance_group.instance_group.name
      LOAD_BALANCER_NAME: google_compute_region_backend_service.backend_service.name
    }
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "terminate_invoker" {
  project        = google_cloudfunctions2_function.terminate_function.project
  location       = google_cloudfunctions2_function.terminate_function.location
  cloud_function = google_cloudfunctions2_function.terminate_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== transient ============================
resource "google_cloudfunctions2_function" "transient_function" {
  name        = "${var.prefix}-${var.cluster_name}-transient"
  description = "transient errors"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime      = "go116"
    entry_point  = "Transient"
    worker_pool  = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "transient_invoker" {
  project        = google_cloudfunctions2_function.transient_function.project
  location       = google_cloudfunctions2_function.transient_function.location
  cloud_function = google_cloudfunctions2_function.transient_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== clusterize_finalization ============================
resource "google_cloudfunctions2_function" "clusterize_finalization_function" {
  name        = "${var.prefix}-${var.cluster_name}-clusterize-finalization"
  description = "clusterization finalization"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime = "go116"
    entry_point = "ClusterizeFinalization"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT: var.project
      ZONE: var.zone
      INSTANCE_GROUP: google_compute_instance_group.instance_group.name
      BUCKET: google_storage_bucket.weka_deployment.name
    }
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "clusterize_finalization_invoker" {
  project        = google_cloudfunctions2_function.clusterize_finalization_function.project
  location       = google_cloudfunctions2_function.clusterize_finalization_function.location
  cloud_function = google_cloudfunctions2_function.clusterize_finalization_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== resize ============================
resource "google_cloudfunctions2_function" "resize_function" {
  name        = "${var.prefix}-${var.cluster_name}-resize"
  description = "update db"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime = "go116"
    entry_point = "Resize"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      BUCKET: google_storage_bucket.weka_deployment.name
    }
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "resize_invoker" {
  project        = google_cloudfunctions2_function.resize_function.project
  location       = google_cloudfunctions2_function.resize_function.location
  cloud_function = google_cloudfunctions2_function.resize_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== join_finalization ============================
resource "google_cloudfunctions2_function" "join_finalization_function" {
  name        = "${var.prefix}-${var.cluster_name}-join-finalization"
  description = "join finalization"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime = "go116"
    entry_point = "JoinFinalization"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT: var.project
      ZONE: var.zone
      INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    }
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "join_finalization_invoker" {
  project        = google_cloudfunctions2_function.join_finalization_function.project
  location       = google_cloudfunctions2_function.join_finalization_function.location
  cloud_function = google_cloudfunctions2_function.join_finalization_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== terminate_cluster ============================
resource "google_cloudfunctions2_function" "terminate_cluster_function" {
  name        = "${var.prefix}-${var.cluster_name}-terminate-cluster"
  description = "terminate cluster"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime = "go116"
    entry_point = "TerminateCluster"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }
  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT: var.project
      ZONE: var.zone
      BUCKET : google_storage_bucket.weka_deployment.name
      CLUSTER_NAME: var.cluster_name
    }
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "terminate_cluster_invoker" {
  project        = google_cloudfunctions2_function.terminate_cluster_function.project
  location       = google_cloudfunctions2_function.terminate_cluster_function.location
  cloud_function = google_cloudfunctions2_function.terminate_cluster_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== status ============================
resource "google_cloudfunctions2_function" "status_function" {
  name        = "${var.prefix}-${var.cluster_name}-status"
  description = "get cluster status"
  location    = lookup(var.cloud_functions_region_map, var.region, var.region)
  build_config {
    runtime = "go116"
    entry_point = "Status"
    worker_pool = local.worker_pool_id
    source {
      storage_source {
        bucket = google_storage_bucket.weka_deployment.name
        object = google_storage_bucket_object.cloud_functions_zip.name
      }
    }
  }

  service_config {
    max_instance_count             = 3
    min_instance_count             = 1
    available_memory               = "256Mi"
    timeout_seconds                = 540
    vpc_connector                  = var.vpc_connector
    ingress_settings               = "ALLOW_ALL"
    vpc_connector_egress_settings  = "PRIVATE_RANGES_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = local.sa_email
    environment_variables = {
      PROJECT: var.project
      ZONE: var.zone
      BUCKET : google_storage_bucket.weka_deployment.name
      INSTANCE_GROUP : google_compute_instance_group.instance_group.name
      USER_NAME_ID : google_secret_manager_secret_version.user_secret_key.id
      PASSWORD_ID : google_secret_manager_secret_version.password_secret_key.id
    }
  }
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
  depends_on = [google_project_service.project-function-api, google_project_service.run-api, google_project_service.artifactregistry-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions2_function_iam_member" "status_invoker" {
  project        = google_cloudfunctions2_function.status_function.project
  location       = google_cloudfunctions2_function.status_function.location
  cloud_function = google_cloudfunctions2_function.status_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}
