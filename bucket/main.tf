resource "google_storage_bucket" "weka-infra" {
  name      = "weka-infra-backend"
  project   = "wekaio-rnd"
  location  = "EU"
}