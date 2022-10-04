# ======================== cloud function ============================

locals {
  function_zip_path = "/tmp/${var.project}-${var.cluster_name}-cloud-functions.zip"
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
  depends_on = [data.archive_file.function_zip]
}

# ======================== deploy ============================
resource "google_cloudfunctions_function" "deploy_function" {
  name        = "${var.prefix}-${var.cluster_name}-deploy-${local.function_hash}"
  description = "deploy new instance"
  runtime     = "go116"
  region = lookup(var.cloud_functions_region_map, var.region, var.region)

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Deploy"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    NICS_NUM: var.nics_number
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    GATEWAYS: format("(%s)", join(" ", [for s in data.google_compute_subnetwork.subnets_list_ids: s.gateway_address] ))
    SUBNETS: format("(%s)", join(" ", [for s in data.google_compute_subnetwork.subnets_list_ids: s.ip_cidr_range] ))
    USER_NAME_ID: google_secret_manager_secret_version.user_secret_key.id
    PASSWORD_ID: google_secret_manager_secret_version.password_secret_key.id
    TOKEN_ID: var.private_network ? "" : google_secret_manager_secret_version.token_secret_key[0].id
    BUCKET : google_storage_bucket.weka_deployment.name
    INSTALL_URL: var.install_url != "" ? var.install_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"
    CLUSTERIZE_URL:google_cloudfunctions_function.clusterize_function.https_trigger_url
    JOIN_FINALIZATION_URL:google_cloudfunctions_function.join_finalization_function.https_trigger_url
  }
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash,
    ]
  }
}


# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "deploy_invoker" {
  project        = google_cloudfunctions_function.deploy_function.project
  region         = google_cloudfunctions_function.deploy_function.region
  cloud_function = google_cloudfunctions_function.deploy_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [
      google_cloudfunctions_function.deploy_function.labels
    ]
  }
}


resource "google_secret_manager_secret_iam_binding" "member-sa-username-secret" {
  project   = google_secret_manager_secret.secret_weka_username.project
  secret_id = google_secret_manager_secret.secret_weka_username.id
  role      = "roles/secretmanager.secretAccessor"
  members    = ["serviceAccount:${var.sa_email}"]
}


resource "google_secret_manager_secret_iam_binding" "member-sa-password-secret" {
  project   = google_secret_manager_secret.secret_weka_password.project
  secret_id = google_secret_manager_secret.secret_weka_password.id
  role      = "roles/secretmanager.secretAccessor"
  members   = ["serviceAccount:${var.sa_email}"]
}

# ======================== fetch ============================
resource "google_cloudfunctions_function" "fetch_function" {
  name        = "${var.prefix}-${var.cluster_name}-fetch--${local.function_hash}"
  description = "fetch cluster info"
  runtime     = "go116"
  region = lookup(var.cloud_functions_region_map, var.region, var.region)

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Fetch"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    BUCKET : google_storage_bucket.weka_deployment.name
    USER_NAME_ID: google_secret_manager_secret_version.user_secret_key.id
    PASSWORD_ID: google_secret_manager_secret_version.password_secret_key.id
  }
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]

}


# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "fetch_invoker" {
  project        = google_cloudfunctions_function.fetch_function.project
  region         = google_cloudfunctions_function.fetch_function.region
  cloud_function = google_cloudfunctions_function.fetch_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
  }
}

# ======================== scale_down ============================
resource "google_cloudfunctions_function" "scale_down_function" {
  name        = "${var.prefix}-${var.cluster_name}-scale-down-${local.function_hash}"
  description = "scale cluster down"
  runtime     = "go116"
  region = lookup(var.cloud_functions_region_map, var.region, var.region)

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "ScaleDown"
  vpc_connector         = var.vpc_connector
  ingress_settings      = "ALLOW_ALL"
  vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "scale_invoker" {
  project        = google_cloudfunctions_function.scale_down_function.project
  region         = google_cloudfunctions_function.scale_down_function.region
  cloud_function = google_cloudfunctions_function.scale_down_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
  }
}
# ======================== scale_up ============================
resource "google_cloudfunctions_function" "scale_up_function" {
  name        = "${var.prefix}-${var.cluster_name}-scale-up-${local.function_hash}"
  description = "scale cluster up"
  runtime     = "go116"
  timeout     = 540
  region = lookup(var.cloud_functions_region_map, var.region, var.region)

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "ScaleUp"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    CLUSTER_NAME: var.cluster_name
    BACKEND_TEMPLATE: google_compute_instance_template.backends-template.id
    BUCKET : google_storage_bucket.weka_deployment.name
    INSTANCE_BASE_NAME: "${var.prefix}-${var.cluster_name}-vm"
  }
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "scale_up_invoker" {
  project        = google_cloudfunctions_function.scale_up_function.project
  region         = google_cloudfunctions_function.scale_up_function.region
  cloud_function = google_cloudfunctions_function.scale_up_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
  }
}


# ======================== clusterize ============================
resource "google_cloudfunctions_function" "clusterize_function" {
  name        = "${var.prefix}-${var.cluster_name}-clusterize-${local.function_hash}"
  description = "return clusterize script"
  runtime     = "go116"
  timeout     = 540
  region = lookup(var.cloud_functions_region_map, var.region, var.region)

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Clusterize"
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
    CLUSTERIZE_FINALIZATION_URL: google_cloudfunctions_function.clusterize_finalization_function.https_trigger_url
  }
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "clusterize_invoker" {
  project        = google_cloudfunctions_function.clusterize_function.project
  region         = google_cloudfunctions_function.clusterize_function.region
  cloud_function = google_cloudfunctions_function.clusterize_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
  }}

# ======================== terminate ============================
resource "google_cloudfunctions_function" "terminate_function" {
  name        = "${var.prefix}-${var.cluster_name}-terminate-${local.function_hash}"
  description = "terminate instances"
  runtime     = "go116"
  timeout     = 540
  region = lookup(var.cloud_functions_region_map, var.region, var.region)

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Terminate"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    LOAD_BALANCER_NAME: google_compute_region_backend_service.backend_service.name
  }
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "terminate_invoker" {
  project        = google_cloudfunctions_function.terminate_function.project
  region         = google_cloudfunctions_function.terminate_function.region
  cloud_function = google_cloudfunctions_function.terminate_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
  }}

# ======================== transient ============================
resource "google_cloudfunctions_function" "transient_function" {
  name        = "${var.prefix}-${var.cluster_name}-transient-${local.function_hash}"
  description = "transient errors"
  runtime     = "go116"
  timeout     = 540
  region = lookup(var.cloud_functions_region_map, var.region, var.region)

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Transient"
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "transient_invoker" {
  project        = google_cloudfunctions_function.transient_function.project
  region         = google_cloudfunctions_function.transient_function.region
  cloud_function = google_cloudfunctions_function.transient_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
  }}

# ======================== clusterize_finalization ============================
resource "google_cloudfunctions_function" "clusterize_finalization_function" {
  name        = "${var.prefix}-${var.cluster_name}-clusterize-finalization-${local.function_hash}"
  description = "clusterization finalization"
  runtime     = "go116"
  timeout     = 540
  region = lookup(var.cloud_functions_region_map, var.region, var.region)

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "ClusterizeFinalization"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    BUCKET: google_storage_bucket.weka_deployment.name
  }
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "clusterize_finalization_invoker" {
  project        = google_cloudfunctions_function.clusterize_finalization_function.project
  region         = google_cloudfunctions_function.clusterize_finalization_function.region
  cloud_function = google_cloudfunctions_function.clusterize_finalization_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
  }}

# ======================== resize ============================
resource "google_cloudfunctions_function" "resize_function" {
  name        = "${var.prefix}-${var.cluster_name}-resize-${local.function_hash}"
  description = "update db"
  runtime     = "go116"
  timeout     = 540

  region = lookup(var.cloud_functions_region_map, var.region, var.region)
  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Resize"
  environment_variables = {
    BUCKET: google_storage_bucket.weka_deployment.name
  }
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "resize_invoker" {
  project        = google_cloudfunctions_function.resize_function.project
  region         = google_cloudfunctions_function.resize_function.region
  cloud_function = google_cloudfunctions_function.resize_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
  }}

# ======================== join_finalization ============================
resource "google_cloudfunctions_function" "join_finalization_function" {
  name        = "${var.prefix}-${var.cluster_name}-join-finalization-${local.function_hash}"
  description = "join finalization"
  runtime     = "go116"
  timeout     = 540
  region = lookup(var.cloud_functions_region_map, var.region, var.region)

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "JoinFinalization"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
  }
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_functions_zip.md5hash
    ]
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "join_finalization_invoker" {
  project        = google_cloudfunctions_function.join_finalization_function.project
  region         = google_cloudfunctions_function.join_finalization_function.region
  cloud_function = google_cloudfunctions_function.join_finalization_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
  }
}

locals {
  function_hash = replace(google_storage_bucket_object.cloud_functions_zip.md5hash,"=","")
}
# ======================== terminate_cluster ============================
resource "google_cloudfunctions_function" "terminate_cluster_function" {
  name        = "${var.prefix}-${var.cluster_name}-terminate-cluster-${local.function_hash}"
  description = "terminate cluster"
  runtime     = "go116"
  timeout     = 540
  region = lookup(var.cloud_functions_region_map, var.region, var.region)

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.weka_deployment.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "TerminateCluster"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    BUCKET : google_storage_bucket.weka_deployment.name
    CLUSTER_NAME: var.cluster_name
  }
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "terminate_cluster_invoker" {
  project        = google_cloudfunctions_function.terminate_cluster_function.project
  region         = google_cloudfunctions_function.terminate_cluster_function.region
  cloud_function = google_cloudfunctions_function.terminate_cluster_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
  lifecycle {
    create_before_destroy = true
  }
}
