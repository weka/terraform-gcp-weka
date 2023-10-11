terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>4.38.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~>3.2.1"
    }
  }
  required_version = ">=1.3.1"
}
