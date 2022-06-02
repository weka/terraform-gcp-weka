resource "google_storage_bucket" "weka-infra" {
  name      = var.bucket_name
  project   = var.project
  location  = var.location
}
