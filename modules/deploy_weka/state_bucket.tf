resource "google_storage_bucket" "state_bucket" {
  name     = "${var.prefix}-${var.cluster_name}-${var.project}-state"
  location = var.bucket-location
}

resource "google_storage_bucket_object" "state" {
  name   = "state"
  bucket = google_storage_bucket.state_bucket.name
  content_type = "application/json"
  content = "{\"initial_size\":${var.cluster_size}, \"desired_size\":${var.cluster_size}, \"instances\":[], \"clusterized\":false}"

  lifecycle {
    ignore_changes = all
  }
}
