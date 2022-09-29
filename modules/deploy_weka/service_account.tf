# ===================== service account ===================
resource "google_service_account" "internal-sa" {
  account_id   = "${var.prefix}-internal-sa"
  display_name = "A service account for deploy weka"
  project = var.project
}


resource "google_project_iam_member" "sa-member-role" {
  for_each = toset([
    "roles/secretmanager.admin",
    "roles/secretmanager.secretAccessor",
    "roles/compute.serviceAgent",
    "roles/compute.admin",
    "roles/cloudfunctions.admin",
    "roles/cloudfunctions.serviceAgent",
    "roles/workflows.admin",
    "roles/storage.admin",
    "roles/cloudscheduler.admin",
    "roles/cloudscheduler.serviceAgent",
    "roles/vpcaccess.admin",
    "roles/vpcaccess.serviceAgent"
  ])
  role = each.key
  member = "serviceAccount:${google_service_account.internal-sa.email}"
  project = var.project
}