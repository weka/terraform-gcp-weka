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

data "google_storage_bucket" "cloud_functions_bucket" {
  name = google_storage_bucket.cloud_functions.name
}

resource "google_storage_bucket_object" "cloud_functions_zip" {
  name   = "${var.prefix}-${var.cluster_name}-cloud-functions.zip"
  bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source = "cloud-functions.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

# ======================== join ============================
resource "google_cloudfunctions_function" "join_function" {
  name        = "${var.prefix}-${var.cluster_name}-join"
  description = "join new instance"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Join"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    CLUSTER_NAME: var.cluster_name
    GATEWAYS: local.gws_addresses
    SUBNETS: format("(%s)", join(" ", var.subnets_range ))
    USER_NAME_ID: google_secret_manager_secret_version.user_secret_key.id
    PASSWORD_ID: google_secret_manager_secret_version.password_secret_key.id
  }

  depends_on = [google_project_service.project-function-api]
}


# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "join_invoker" {
  project        = google_cloudfunctions_function.join_function.project
  region         = google_cloudfunctions_function.join_function.region
  cloud_function = google_cloudfunctions_function.join_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}


resource "google_secret_manager_secret_iam_member" "member-sa-username-secret" {
  project   = google_secret_manager_secret.secret_weka_username.project
  secret_id = google_secret_manager_secret.secret_weka_username.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.project}@appspot.gserviceaccount.com"
}


resource "google_secret_manager_secret_iam_member" "member-sa-password-secret" {
  project   = google_secret_manager_secret.secret_weka_password.project
  secret_id = google_secret_manager_secret.secret_weka_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.project}@appspot.gserviceaccount.com"
}

# ======================== fetch ============================
resource "google_cloudfunctions_function" "fetch_function" {
  name        = "${var.prefix}-${var.cluster_name}-fetch"
  description = "fetch cluster info"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Fetch"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    CLUSTER_NAME: var.cluster_name
    COLLECTION_NAME: "${var.prefix}-${var.cluster_name}-collection"
    DOCUMENT_NAME: "${var.prefix}-${var.cluster_name}-document"
    USER_NAME_ID: google_secret_manager_secret_version.user_secret_key.id
    PASSWORD_ID: google_secret_manager_secret_version.password_secret_key.id
  }

  depends_on = [google_project_service.project-function-api]
}


# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "fetch_invoker" {
  project        = google_cloudfunctions_function.fetch_function.project
  region         = google_cloudfunctions_function.fetch_function.region
  cloud_function = google_cloudfunctions_function.fetch_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ======================== scale_down ============================
resource "google_cloudfunctions_function" "scale_down_function" {
  name        = "${var.prefix}-${var.cluster_name}-scale-down"
  description = "scale cluster down"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "ScaleDown"
  vpc_connector         = var.vpc-connector
  ingress_settings      = "ALLOW_ALL"
  vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"

  depends_on = [google_project_service.project-function-api]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "scale_invoker" {
  project        = google_cloudfunctions_function.scale_down_function.project
  region         = google_cloudfunctions_function.scale_down_function.region
  cloud_function = google_cloudfunctions_function.scale_down_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}
# ======================== scale_up ============================
resource "google_cloudfunctions_function" "scale_up_function" {
  name        = "${var.prefix}-${var.cluster_name}-scale-up"
  description = "scale cluster up"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "ScaleUp"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    BACKEND_TEMPLATE: google_compute_instance_template.backends-template.id
    CLUSTERIZE_TEMPLATE: google_compute_instance_template.clusterize-template.id
    JOIN_TEMPLATE: google_compute_instance_template.join-template.id
    COLLECTION_NAME: "${var.prefix}-${var.cluster_name}-collection"
    DOCUMENT_NAME: "${var.prefix}-${var.cluster_name}-document"
    INSTANCE_BASE_NAME: "${var.prefix}-${var.cluster_name}-vm"
    CLOUD_FUNCTION_URL: google_cloudfunctions_function.get_size_function.https_trigger_url
  }
  depends_on = [google_cloudfunctions_function.get_size_function]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "scale_up_invoker" {
  project        = google_cloudfunctions_function.scale_up_function.project
  region         = google_cloudfunctions_function.scale_up_function.region
  cloud_function = google_cloudfunctions_function.scale_up_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}


# ======================== clusterize ============================
resource "google_cloudfunctions_function" "clusterize_function" {
  name        = "${var.prefix}-${var.cluster_name}-clusterize"
  description = "return clusterize scipt"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
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
    GET_SIZE_URL: google_cloudfunctions_function.get_size_function.https_trigger_url
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "clusterize_invoker" {
  project        = google_cloudfunctions_function.clusterize_function.project
  region         = google_cloudfunctions_function.clusterize_function.region
  cloud_function = google_cloudfunctions_function.clusterize_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ======================== terminate ============================
resource "google_cloudfunctions_function" "terminate_function" {
  name        = "${var.prefix}-${var.cluster_name}-terminate"
  description = "terminate instances"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Terminate"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    COLLECTION_NAME: "${var.prefix}-${var.cluster_name}-collection"
    DOCUMENT_NAME: "${var.prefix}-${var.cluster_name}-document"
    LOAD_BALANCER_NAME: google_compute_region_backend_service.backend_service.name
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "terminate_invoker" {
  project        = google_cloudfunctions_function.terminate_function.project
  region         = google_cloudfunctions_function.terminate_function.region
  cloud_function = google_cloudfunctions_function.terminate_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ======================== transient ============================
resource "google_cloudfunctions_function" "transient_function" {
  name        = "${var.prefix}-${var.cluster_name}-transient"
  description = "transient errors"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Transient"
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "transient_invoker" {
  project        = google_cloudfunctions_function.transient_function.project
  region         = google_cloudfunctions_function.transient_function.region
  cloud_function = google_cloudfunctions_function.transient_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ======================== bunch ============================
resource "google_cloudfunctions_function" "bunch_function" {
  name        = "${var.prefix}-${var.cluster_name}-bunch"
  description = "bunch instances"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Bunch"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "bunch_invoker" {
  project        = google_cloudfunctions_function.bunch_function.project
  region         = google_cloudfunctions_function.bunch_function.region
  cloud_function = google_cloudfunctions_function.bunch_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ======================== update_db ============================
resource "google_cloudfunctions_function" "update_db_function" {
  name        = "${var.prefix}-${var.cluster_name}-update-db"
  description = "update db"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "UpdateDb"
  environment_variables = {
    PROJECT: var.project
    COLLECTION_NAME: "${var.prefix}-${var.cluster_name}-collection"
    DOCUMENT_NAME: "${var.prefix}-${var.cluster_name}-document"
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "update_db_invoker" {
  project        = google_cloudfunctions_function.update_db_function.project
  region         = google_cloudfunctions_function.update_db_function.region
  cloud_function = google_cloudfunctions_function.update_db_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ======================== increment ============================
resource "google_cloudfunctions_function" "increment_function" {
  name        = "${var.prefix}-${var.cluster_name}-increment"
  description = "increment db"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Increment"
  environment_variables = {
    PROJECT: var.project
    COLLECTION_NAME: "${var.prefix}-${var.cluster_name}-collection"
    DOCUMENT_NAME: "${var.prefix}-${var.cluster_name}-document"
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "increment_invoker" {
  project        = google_cloudfunctions_function.increment_function.project
  region         = google_cloudfunctions_function.increment_function.region
  cloud_function = google_cloudfunctions_function.increment_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ======================== get_db_value ============================
resource "google_cloudfunctions_function" "get_db_value_function" {
  name        = "${var.prefix}-${var.cluster_name}-get-db-value"
  description = "get value from db"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "GetDbValue"
  environment_variables = {
    PROJECT: var.project
    COLLECTION_NAME: "${var.prefix}-${var.cluster_name}-collection"
    DOCUMENT_NAME: "${var.prefix}-${var.cluster_name}-document"
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "get_db_value_invoker" {
  project        = google_cloudfunctions_function.get_db_value_function.project
  region         = google_cloudfunctions_function.get_db_value_function.region
  cloud_function = google_cloudfunctions_function.get_db_value_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ======================== get_size ============================
resource "google_cloudfunctions_function" "get_size_function" {
  name        = "${var.prefix}-${var.cluster_name}-get-size"
  description = "get cluster instance group size"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "GetSize"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "get_size_invoker" {
  project        = google_cloudfunctions_function.get_size_function.project
  region         = google_cloudfunctions_function.get_size_function.region
  cloud_function = google_cloudfunctions_function.get_size_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ======================== protect ============================
resource "google_cloudfunctions_function" "protect_function" {
  name        = "${var.prefix}-${var.cluster_name}-protect"
  description = "add instance deletion protection"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = data.google_storage_bucket.cloud_functions_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_functions_zip.name
  trigger_http          = true
  entry_point           = "Protect"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "protect_invoker" {
  project        = google_cloudfunctions_function.protect_function.project
  region         = google_cloudfunctions_function.protect_function.region
  cloud_function = google_cloudfunctions_function.protect_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}
