terraform {
  backend "gcs" {
    bucket = "weka-infra-backend"
    prefix = "vm-yum-repo-state/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>4.27.0"
    }
  }
  required_version = ">=1.2.4"
}