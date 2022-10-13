terraform {
  backend "gcs" {
    bucket  = "weka-infra-backend"
    prefix  = "ci/service-account"
  }
  required_version = ">=1.2.4"
}

# ===================== service account ===================
resource "google_service_account" "sa" {
  account_id   = "${var.prefix}-${var.sa_name}"
  display_name = "A service account for weka ci"
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
    "roles/iam.serviceAccountKeyAdmin",
    "roles/vpcaccess.admin",
    "roles/vpcaccess.serviceAgent",
    "roles/cloudscheduler.admin",
    "roles/cloudscheduler.serviceAgent",
    "roles/dns.admin",
    "roles/pubsub.editor"
  ])
  role = each.key
  member = "serviceAccount:${google_service_account.sa.email}"
  project = var.project
}
