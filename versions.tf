terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=6.21.0"
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
  required_version = ">=1.3.1"
}
