locals {
  state_bucket_name        = var.state_bucket_name == "" ? ["${var.prefix}-${var.cluster_name}-${var.project_id}"] : []
  obs_bucket_name          = var.tiering_obs_name == "" ? ["${var.project_id}-${var.prefix}-${var.cluster_name}-obs"] : []
  object_state_bucket_name = var.state_bucket_name == "" ? ["${var.prefix}-${var.cluster_name}-${var.project_id}"] : [var.state_bucket_name]
  object_obs_bucket_name   = var.tiering_obs_name == "" ? ["${var.project_id}-${var.prefix}-${var.cluster_name}-obs"] : [var.tiering_obs_name]

  bucket_list_name = concat(local.obs_bucket_name, local.state_bucket_name)
  object_list_name = concat(local.object_obs_bucket_name, local.object_state_bucket_name)

  network_project_roles = var.network_project_id != "" ? toset([
    "roles/compute.networkUser",
    "roles/compute.serviceAgent",
    "roles/vpcaccess.serviceAgent",
  ]) : []
}

# ===================== service account ===================
resource "google_service_account" "sa" {
  account_id   = "${var.prefix}-${var.service_account_name}"
  display_name = "A service account for deploy weka"
}

resource "google_project_iam_member" "sa_member_role" {
  for_each = toset([
    "roles/secretmanager.secretAccessor",
    "roles/compute.serviceAgent",
    "roles/compute.loadBalancerServiceUser", # needed for GetHealthRegionBackendServiceRequest
    "roles/cloudfunctions.developer",
    "roles/workflows.invoker",
    "roles/vpcaccess.serviceAgent",
    "roles/pubsub.subscriber"
  ])
  role    = each.key
  member  = "serviceAccount:${google_service_account.sa.email}"
  project = var.project_id
}


resource "google_project_iam_member" "network_project_sa_member_role" {
  for_each = local.network_project_roles
  role     = each.key
  member   = "serviceAccount:${google_service_account.sa.email}"
  project  = var.network_project_id
}

resource "google_project_iam_member" "storage_admin" {
  count   = length(local.bucket_list_name)
  project = var.project_id
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
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.sa.email}"

  condition {
    title       = "Add object admin storage permission to ${local.object_list_name[count.index]}"
    description = "Add object admin storage permission"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${local.object_list_name[count.index]}\")"
  }
  depends_on = [google_service_account.sa]
}

resource "google_project_iam_member" "weka_tar_object_iam_member" {
  count   = var.weka_tar_bucket_name != "" ? 1 : 0
  project = var.weka_tar_project_id != "" ? var.weka_tar_project_id : var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.sa.email}"

  condition {
    title       = "Add object viewer storage permission to ${var.weka_tar_bucket_name}"
    description = "Add object viewer storage permission"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${var.weka_tar_bucket_name}\")"
  }
  depends_on = [google_service_account.sa]
}
