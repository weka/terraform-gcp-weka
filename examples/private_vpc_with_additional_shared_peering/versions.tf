terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>4.38.0"
      configuration_aliases = [google.shared-vpc]
    }
  }
  required_version = ">=1.3.1"
}
