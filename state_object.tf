resource "google_storage_bucket_object" "state" {
  name         = "state"
  bucket       = local.state_bucket
  content_type = "application/json"
  content      = "{\"initial_size\":${var.cluster_size}, \"desired_size\":${var.cluster_size}, \"instances\":[], \"clusterized\":false, \"clusterization_target\":${var.cluster_size}}"

  lifecycle {
    ignore_changes = all
  }
}
