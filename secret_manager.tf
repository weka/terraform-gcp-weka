resource "google_project_service" "secret_manager" {
  service  = "secretmanager.googleapis.com"
}

resource "google_secret_manager_secret" "secret_weka_password" {
  secret_id = "weka_password"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret_version" "secret-key" {
  secret      = google_secret_manager_secret.secret_weka_password.id
  secret_data = random_password.password.result
}

resource "null_resource" "get_secret_from_secret_manager" {
  provisioner "local-exec" {
    command = <<-EOT
            secret_name=$(echo "${google_secret_manager_secret.secret_weka_password.id}" |awk -F"/" '{print $4}' )
            gcloud secrets versions access latest --secret=$secret_name
      EOT
    interpreter = ["bash", "-ce"]
  }

  depends_on = [google_secret_manager_secret.secret_weka_password,google_secret_manager_secret_version.secret-key ]
}