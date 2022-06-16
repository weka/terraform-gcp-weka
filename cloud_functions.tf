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

      cd ../scale
      zip -r scale.zip connectors lib protocol scale.go  go.mod
      mv scale.zip ../../cloud-functions-zip/

      cd ../scale_up
      zip -r scale_up.zip scale_up.go go.mod
      mv scale_up.zip ../../cloud-functions-zip/

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

# ======================== scale ============================

resource "google_storage_bucket_object" "scale_zip" {
  name   = "scale.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/scale.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "scale_function" {
  name        = "scale"
  description = "scale cluster"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.scale_zip.name
  trigger_http          = true
  entry_point           = "Scale"
  vpc_connector         = google_vpc_access_connector.connector.name
  ingress_settings      = "ALLOW_ALL"
  vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"

  depends_on = [google_vpc_access_connector.connector]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "scale_invoker" {
  project        = google_cloudfunctions_function.scale_function.project
  region         = google_cloudfunctions_function.scale_function.region
  cloud_function = google_cloudfunctions_function.scale_function.name

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

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.scale_up_zip.name
  trigger_http          = true
  entry_point           = "ScaleUp"
  environment_variables = {
    PROJECT: var.project
    ZONE: var.zone
    INSTANCE_GROUP: google_compute_instance_group.instance_group.name
    CLUSTER_NAME: var.cluster_name
    BACKEND_TEMPLATE: google_compute_instance_template.backends-template.id
    JOIN_TEMPLATE: google_compute_instance_template.join-template.id
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