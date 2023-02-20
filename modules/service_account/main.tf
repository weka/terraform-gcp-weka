# ===================== service account ===================
resource "google_service_account" "sa" {
  account_id   = "${var.prefix}-${var.service_account_name}"
  display_name = "A service account for deploy weka"
  project = var.project
}


resource "google_project_iam_member" "sa-member-role" {
  for_each = toset([
    "roles/secretmanager.secretAccessor",
    "roles/compute.serviceAgent",
    "roles/cloudfunctions.developer",
    "roles/workflows.invoker",
    "roles/storage.objectAdmin",
    "roles/vpcaccess.serviceAgent",
    "roles/pubsub.subscriber"
  ])
  role = each.key
  member = "serviceAccount:${google_service_account.sa.email}"
  project = var.project
}
