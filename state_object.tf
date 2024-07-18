resource "google_storage_bucket_object" "state" {
  name         = "state"
  bucket       = local.state_bucket
  content_type = "application/json"
  content      = "{\"initial_size\":${var.cluster_size}, \"desired_size\":${var.cluster_size}, \"instances\":[], \"clusterized\":false, \"clusterization_target\":${var.cluster_size}}"

  lifecycle {
    ignore_changes = all
  }
}

resource "google_storage_bucket_object" "nfs_state" {
  count        = var.nfs_setup_protocol ? 1 : 0
  name         = "nfs_state"
  bucket       = local.state_bucket
  content_type = "application/json"
  content = jsonencode({
    initial_size          = var.nfs_protocol_gateways_number
    desired_size          = var.nfs_protocol_gateways_number
    instances             = []
    clusterized           = false
    clusterization_target = var.nfs_protocol_gateways_number
  })

  lifecycle {
    ignore_changes = all
  }
}
