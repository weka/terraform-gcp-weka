terraform {
  backend "gcs" {
    bucket = "weka-infra-backend"
    prefix = "terrafrom/state"
  }
}

provider "google" {
  project = var.project
}
