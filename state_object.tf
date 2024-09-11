locals {
  state_object_name     = "state"
  nfs_state_object_name = "nfs_state"
}

resource "google_storage_bucket_object" "state" {
  name         = local.state_object_name
  bucket       = local.state_bucket
  content_type = "application/json"
  content      = "{\"initial_size\":${var.cluster_size}, \"desired_size\":${var.cluster_size}, \"instances\":[], \"clusterized\":false, \"clusterization_target\":${var.cluster_size}}"
  lifecycle {
    ignore_changes = all
  }
  depends_on = [google_cloudfunctions2_function.cloud_internal_function]
}

resource "google_storage_bucket_object" "nfs_state" {
  count        = var.nfs_setup_protocol ? 1 : 0
  name         = local.nfs_state_object_name
  bucket       = local.state_bucket
  content_type = "application/json"
  content = jsonencode({
    initial_size           = var.nfs_protocol_gateways_number
    desired_size           = var.nfs_protocol_gateways_number
    instances              = []
    clusterized            = false
    clusterization_target  = var.nfs_protocol_gateways_number
    nfs_instances_migrated = false
  })
  lifecycle {
    ignore_changes = all
  }
  depends_on = [google_cloudfunctions2_function.cloud_internal_function]
}
