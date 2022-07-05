# ======================== cloud function ============================

resource "null_resource" "generate_cloud_functions_zips" {
  provisioner "local-exec" {
    command = <<-EOT
      cd cloud-functions
      zip -r ../cloud-functions.zip * -x cloud-functions/cloud_functions_test.go
    EOT
    interpreter = ["bash", "-ce"]
  }
}

# ================== function bucket =======================
resource "google_storage_bucket" "cloud_functions" {
  name     = "${var.prefix}-${var.cluster_name}-cloud-functions"
  location = var.bucket-location
}

resource "google_storage_bucket_object" "cloud_functions_zip" {
  name   = "${var.prefix}-${var.cluster_name}-cloud-functions.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

# ======================== deploy ============================
resource "google_cloudfunctions_function" "deploy_function" {
  name        = "${var.prefix}-${var.cluster_name}-deploy"
  description = "deploy new instance"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Deploy"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    GATEWAYS: local.gws_addresses
    SUBNETS: format("(%s)", join(" ", var.subnets_range ))
    USER_NAME_ID: google_secret_manager_secret_version.user_secret_key.id
    PASSWORD_ID: google_secret_manager_secret_version.password_secret_key.id
    TOKEN_ID: google_secret_manager_secret_version.token_secret_key.id
    BUCKET : google_storage_bucket.state_bucket.name
    INSTALL_URL: "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"
    CLUSTERIZE_URL:google_cloudfunctions_function.clusterize_function.https_trigger_url
    INCREMENT_URL:google_cloudfunctions_function.increment_function.https_trigger_url
    PROTECT_URL:google_cloudfunctions_function.protect_function.https_trigger_url
    BUNCH_URL:google_cloudfunctions_function.bunch_function.https_trigger_url
    GET_INSTANCES_URL: google_cloudfunctions_function.get_instances_function.https_trigger_url
  }
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]
}


# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "deploy_invoker" {
  project        = google_cloudfunctions_function.deploy_function.project
  region         = google_cloudfunctions_function.deploy_function.region
  cloud_function = google_cloudfunctions_function.deploy_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
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

resource "google_secret_manager_secret_iam_member" "member-sa-token" {
  project   = google_secret_manager_secret.secret_token.project
  secret_id = google_secret_manager_secret.secret_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.sa_email}"
}

# ======================== fetch ============================
resource "google_cloudfunctions_function" "fetch_function" {
  name        = "${var.prefix}-${var.cluster_name}-fetch"
  description = "fetch cluster info"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Fetch"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    BUCKET : google_storage_bucket.state_bucket.name
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
}

# ======================== scale_down ============================
resource "google_cloudfunctions_function" "scale_down_function" {
  name        = "${var.prefix}-${var.cluster_name}-scale-down"
  description = "scale cluster down"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "ScaleDown"
  vpc_connector         = var.vpc-connector
  ingress_settings      = "ALLOW_ALL"
  vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
  service_account_email = var.sa_email
  depends_on = [google_project_service.project-function-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "scale_invoker" {
  project        = google_cloudfunctions_function.scale_down_function.project
  region         = google_cloudfunctions_function.scale_down_function.region
  cloud_function = google_cloudfunctions_function.scale_down_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}
# ======================== scale_up ============================
resource "google_cloudfunctions_function" "scale_up_function" {
  name        = "${var.prefix}-${var.cluster_name}-scale-up"
  description = "scale cluster up"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "ScaleUp"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    BACKEND_TEMPLATE: google_compute_instance_template.backends-template.id
    BUCKET : google_storage_bucket.state_bucket.name
    INSTANCE_BASE_NAME: "${var.prefix}-${var.cluster_name}-vm"
  }
  service_account_email = var.sa_email
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "scale_up_invoker" {
  project        = google_cloudfunctions_function.scale_up_function.project
  region         = google_cloudfunctions_function.scale_up_function.region
  cloud_function = google_cloudfunctions_function.scale_up_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}


# ======================== clusterize ============================
resource "google_cloudfunctions_function" "clusterize_function" {
  name        = "${var.prefix}-${var.cluster_name}-clusterize"
  description = "return clusterize script"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Clusterize"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    HOSTS_NUM: var.cluster_size
    NICS_NUM: var.nics_number
    GWS: local.gws_addresses
    CLUSTER_NAME: var.cluster_name
    NVMES_NUM: var.nvmes_number
    USER_NAME_ID: google_secret_manager_secret_version.user_secret_key.id
    PASSWORD_ID: google_secret_manager_secret_version.password_secret_key.id
    INSTANCE_BASE_NAME: "${var.prefix}-${var.cluster_name}-vm"
  }
  service_account_email = var.sa_email
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "clusterize_invoker" {
  project        = google_cloudfunctions_function.clusterize_function.project
  region         = google_cloudfunctions_function.clusterize_function.region
  cloud_function = google_cloudfunctions_function.clusterize_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== terminate ============================
resource "google_cloudfunctions_function" "terminate_function" {
  name        = "${var.prefix}-${var.cluster_name}-terminate"
  description = "terminate instances"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
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
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "terminate_invoker" {
  project        = google_cloudfunctions_function.terminate_function.project
  region         = google_cloudfunctions_function.terminate_function.region
  cloud_function = google_cloudfunctions_function.terminate_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== transient ============================
resource "google_cloudfunctions_function" "transient_function" {
  name        = "${var.prefix}-${var.cluster_name}-transient"
  description = "transient errors"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Transient"
  service_account_email = var.sa_email
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "transient_invoker" {
  project        = google_cloudfunctions_function.transient_function.project
  region         = google_cloudfunctions_function.transient_function.region
  cloud_function = google_cloudfunctions_function.transient_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== bunch ============================
resource "google_cloudfunctions_function" "bunch_function" {
  name        = "${var.prefix}-${var.cluster_name}-bunch"
  description = "bunch instances"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Bunch"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
  }
  service_account_email = var.sa_email
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "bunch_invoker" {
  project        = google_cloudfunctions_function.bunch_function.project
  region         = google_cloudfunctions_function.bunch_function.region
  cloud_function = google_cloudfunctions_function.bunch_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== resize ============================
resource "google_cloudfunctions_function" "resize_function" {
  name        = "${var.prefix}-${var.cluster_name}-resize"
  description = "update db"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Resize"
  environment_variables = {
    BUCKET: google_storage_bucket.state_bucket.name
  }
  service_account_email = var.sa_email
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "resize_invoker" {
  project        = google_cloudfunctions_function.resize_function.project
  region         = google_cloudfunctions_function.resize_function.region
  cloud_function = google_cloudfunctions_function.resize_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== increment ============================
resource "google_cloudfunctions_function" "increment_function" {
  name        = "${var.prefix}-${var.cluster_name}-increment"
  description = "increment db"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Increment"
  environment_variables = {
    BUCKET: google_storage_bucket.state_bucket.name
  }
  service_account_email = var.sa_email
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "increment_invoker" {
  project        = google_cloudfunctions_function.increment_function.project
  region         = google_cloudfunctions_function.increment_function.region
  cloud_function = google_cloudfunctions_function.increment_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== get_instances ============================
resource "google_cloudfunctions_function" "get_instances_function" {
  name        = "${var.prefix}-${var.cluster_name}-get-instances"
  description = "get cluster instance group size"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "GetInstances"
  environment_variables = {
    BUCKET : google_storage_bucket.state_bucket.name
  }
  service_account_email = var.sa_email
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "get_instances_invoker" {
  project        = google_cloudfunctions_function.get_instances_function.project
  region         = google_cloudfunctions_function.get_instances_function.region
  cloud_function = google_cloudfunctions_function.get_instances_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}

# ======================== protect ============================
resource "google_cloudfunctions_function" "protect_function" {
  name        = "${var.prefix}-${var.cluster_name}-protect"
  description = "add instance deletion protection"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Protect"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
  }
  service_account_email = var.sa_email
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "protect_invoker" {
  project        = google_cloudfunctions_function.protect_function.project
  region         = google_cloudfunctions_function.protect_function.region
  cloud_function = google_cloudfunctions_function.protect_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allAuthenticatedUsers"
}
