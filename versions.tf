terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=6.23.0"
    }
    # the compact placement policy sets max_distance, which is a GCP Preview field that only
    # the beta provider exposes
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">=6.23.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~>2.4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~>0.9.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2.4.0"
    }
  }
  # the secret versions pass their payload through secret_data_wo, a write-only attribute
  required_version = ">=1.11.0"
}
