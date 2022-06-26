# ======================== cloud function ============================

resource "null_resource" "generate_cloud_functions_zips" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p cloud-functions-zip

      cd cloud-functions/join
      zip -r join.zip join.go go.mod
      mv join.zip ../../cloud-functions-zip/

      cd ../fetch
      zip -r fetch.zip fetch.go go.mod
      mv fetch.zip ../../cloud-functions-zip/

      cd ../scale_down
      zip -r scale_down.zip connectors lib protocol scale_down.go  go.mod
      mv scale_down.zip ../../cloud-functions-zip/

      cd ../scale_up
      zip -r scale_up.zip scale_up.go go.mod
      mv scale_up.zip ../../cloud-functions-zip/

      cd ../clusterize
      zip -r clusterize.zip clusterize.go go.mod
      mv clusterize.zip ../../cloud-functions-zip/

      cd ../terminate
      zip -r terminate.zip lib protocol terminate.go go.mod
      mv terminate.zip ../../cloud-functions-zip/

      cd ../transient
      zip -r transient.zip lib protocol transient.go go.mod
      mv transient.zip ../../cloud-functions-zip/

      cd ../bunch
      zip -r bunch.zip bunch.go go.mod
      mv bunch.zip ../../cloud-functions-zip/

      cd ../update_db
      zip -r update_db.zip update_db.go go.mod
      mv update_db.zip ../../cloud-functions-zip/

      cd ../increment
      zip -r increment.zip increment.go go.mod
      mv increment.zip ../../cloud-functions-zip/

      cd ../get_db_value
      zip -r get_db_value.zip get_db_value.go go.mod
      mv get_db_value.zip ../../cloud-functions-zip/

    EOT
    interpreter = ["bash", "-ce"]
  }
}

resource "google_storage_bucket" "cloud_functions" {
  name     = "${var.prefix}-cloud-functions"
  location = "EU"
}

# ======================== join ============================
resource "google_storage_bucket_object" "join_zip" {
  name   = "join.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/join.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}


resource "google_cloudfunctions_function" "join_function" {
  name        = "join"
  description = "join new instance"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.join_zip.name
  trigger_http          = true
  entry_point           = "Join"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    CLUSTER_NAME: var.cluster_name
    GATEWAYS: local.gws_addresses
    SUBNETS: format("(%s)", join(" ",var.subnets))
  }
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
  project = google_secret_manager_secret.secret_weka_username.project
  secret_id = google_secret_manager_secret.secret_weka_username.id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${var.project}@appspot.gserviceaccount.com"
}


resource "google_secret_manager_secret_iam_member" "member-sa-password-secret" {
  project = google_secret_manager_secret.secret_weka_password.project
  secret_id = google_secret_manager_secret.secret_weka_password.id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${var.project}@appspot.gserviceaccount.com"
}

# ======================== fetch ============================

resource "google_storage_bucket_object" "fetch_zip" {
  name   = "fetch.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/fetch.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "fetch_function" {
  name        = "fetch"
  description = "fetch cluster info"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.fetch_zip.name
  trigger_http          = true
  entry_point           = "Fetch"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    CLUSTER_NAME: var.cluster_name
    COLLECTION_NAME: "${var.prefix}-${var.cluster_name}-collection"
    DOCUMENT_NAME: "${var.prefix}-${var.cluster_name}-document"
  }
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

resource "google_storage_bucket_object" "scale_down_zip" {
  name   = "scale_down.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/scale_down.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "scale_down_function" {
  name        = "scale_down"
  description = "scale cluster down"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.scale_down_zip.name
  trigger_http          = true
  entry_point           = "Scale"
  vpc_connector         = google_vpc_access_connector.connector.name
  ingress_settings      = "ALLOW_ALL"
  vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"

  depends_on = [google_vpc_access_connector.connector]
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

resource "google_storage_bucket_object" "scale_up_zip" {
  name   = "scale_up.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/scale_up.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "scale_up_function" {
  name        = "scale_up"
  description = "scale cluster up"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.scale_up_zip.name
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
  }
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

resource "google_storage_bucket_object" "clusterize_zip" {
  name   = "clusterize.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/clusterize.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "clusterize_function" {
  name        = "clusterize"
  description = "return clusterize scipt"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.clusterize_zip.name
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

resource "google_storage_bucket_object" "terminate_zip" {
  name   = "terminate.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/terminate.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "terminate_function" {
  name        = "terminate"
  description = "terminate instances"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.terminate_zip.name
  trigger_http          = true
  entry_point           = "Terminate"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
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

resource "google_storage_bucket_object" "transient_zip" {
  name   = "transient.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/transient.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "transient_function" {
  name        = "transient"
  description = "transient errors"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.transient_zip.name
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

resource "google_storage_bucket_object" "bunch_zip" {
  name   = "bunch.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/bunch.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "bunch_function" {
  name        = "bunch"
  description = "bunch instances"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.bunch_zip.name
  trigger_http          = true
  entry_point           = "Bunch"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    CLUSTER_NAME: var.cluster_name
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

resource "google_storage_bucket_object" "update_db_zip" {
  name   = "update_db.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/update_db.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "update_db_function" {
  name        = "update_db"
  description = "update db"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.update_db_zip.name
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

resource "google_storage_bucket_object" "increment_zip" {
  name   = "increment.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/increment.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "increment_function" {
  name        = "increment"
  description = "increment db"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.increment_zip.name
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

resource "google_storage_bucket_object" "get_db_value_zip" {
  name   = "get_db_value.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/get_db_value.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "get_db_value_function" {
  name        = "get_db_value"
  description = "get value from db"
  runtime     = "go116"
  timeout     = 540

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.get_db_value_zip.name
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
