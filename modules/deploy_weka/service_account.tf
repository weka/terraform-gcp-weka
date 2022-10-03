# ===================== service account ===================
resource "google_service_account" "function-sa" {
  account_id   = "${var.prefix}-function-sa"
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
    "roles/cloudscheduler.serviceAgent",
    "roles/dns.admin"
  ])
  role = each.key
  member = "serviceAccount:${google_service_account.function-sa.email}"
  project = var.project
}

output "outputs-service-account-email" {
  value = google_service_account.function-sa.email
}
