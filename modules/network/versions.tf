terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=4.38.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 3.83.0"
    }
  }
  required_version = ">=1.3.1"
}
