terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=6.21.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">=6.21.0"
    }
  }
  required_version = ">=1.3.1"
}
