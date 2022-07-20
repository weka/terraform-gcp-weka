resource "google_project_service" "secret_manager" {
  service  = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "secret_weka_password" {
  secret_id = "${var.prefix}-${var.cluster_name}-password"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret_version" "password_secret_key" {
  secret      = google_secret_manager_secret.secret_weka_password.id
  secret_data = random_password.password.result

   lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret" "secret_weka_username" {
  secret_id = "${var.prefix}-${var.cluster_name}-username"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret_version" "user_secret_key" {
  secret      = google_secret_manager_secret.secret_weka_username.id
  secret_data = var.weka_username

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret" "secret_token" {
  count = var.private_network ? 0 : 1
  secret_id = "${var.prefix}-${var.cluster_name}-token"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret_version" "token_secret_key" {
  count = var.private_network ? 0 : 1
  secret      = google_secret_manager_secret.secret_token[count.index].id
  secret_data = var.get_weka_io_token

  lifecycle {
    ignore_changes = [secret_data]
  }
}
