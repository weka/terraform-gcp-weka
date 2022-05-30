resource "google_storage_bucket" "weka-infra" {
  name      = "weka-infra-backend"
  project   = var.project
  location  = var.location
}
