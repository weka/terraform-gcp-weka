locals {
  state_bucket_name        = var.state_bucket_name == "" ? ["${var.prefix}-${var.cluster_name}-${var.project}"] : []
  obs_bucket_name          = var.obs_name == "" ? ["${var.project}-${var.prefix}-${var.cluster_name}-obs"] : []
  object_state_bucket_name = var.state_bucket_name == "" ? ["${var.prefix}-${var.cluster_name}-${var.project}"] : [var.state_bucket_name]
  object_obs_bucket_name   = var.obs_name == "" ? ["${var.project}-${var.prefix}-${var.cluster_name}-obs"] : [var.obs_name]

  bucket_list_name          = concat(local.obs_bucket_name,local.state_bucket_name)
  object_list_name          = concat(local.object_obs_bucket_name, local.object_state_bucket_name)
}

# ===================== service account ===================
resource "google_service_account" "sa" {
  account_id   = "${var.prefix}-${var.service_account_name}"
  display_name = "A service account for deploy weka"
  project      = var.project
}

resource "google_project_iam_member" "sa-member-role" {
  for_each = toset([
    "roles/secretmanager.secretAccessor",
    "roles/compute.serviceAgent",
    "roles/cloudfunctions.developer",
    "roles/workflows.invoker",
    "roles/vpcaccess.serviceAgent",
    "roles/pubsub.subscriber"
  ])
  role = each.key
  member = "serviceAccount:${google_service_account.sa.email}"
  project = var.project
}

resource "google_project_iam_member" "storage_admin" {
  count   = length(local.bucket_list_name)
  project = var.project
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.sa.email}"

  condition {
    title       = "Add admin storage permission ${local.bucket_list_name[count.index]}"
    description = "Add admin storage permission"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${local.bucket_list_name[count.index]}\")"
  }
  depends_on = [google_service_account.sa]
}

resource "google_project_iam_member" "object_iam_member" {
  count   = length(local.object_list_name)
  project = var.project
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.sa.email}"

  condition {
    title       = "Add object admin storage permission to ${local.object_list_name[count.index]}"
    description = "Add object admin storage permission"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${local.object_list_name[count.index]}\")"
  }
  depends_on = [google_service_account.sa]
}