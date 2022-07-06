# ===================== service account ===================
resource "google_service_account" "sa" {
  account_id   = "${var.prefix}-${var.sa_name}"
  display_name = "A service account for deploy weka"
  project = var.project
}


resource "google_project_iam_member" "sa-member-role" {
  for_each = toset([
    "roles/secretmanager.admin",
    "roles/secretmanager.secretAccessor",
    "roles/compute.serviceAgent",
    "roles/compute.admin",
    "roles/networkmanagement.admin",
    "roles/cloudfunctions.admin",
    "roles/cloudfunctions.serviceAgent",
    "roles/workflows.admin",
    "roles/storage.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.securityAdmin",
    "roles/vpcaccess.admin",
    "roles/vpcaccess.serviceAgent",
    "roles/cloudscheduler.admin",
    "roles/cloudscheduler.serviceAgent"
  ])
  role = each.key
  member = "serviceAccount:${google_service_account.sa.email}"
  project = var.project
}

resource "google_service_account_key" "sa-key" {
  service_account_id = google_service_account.sa.name
}
