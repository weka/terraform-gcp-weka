terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>5.11.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.84.0"
    }
  }
  required_version = ">=1.3.1"
}
