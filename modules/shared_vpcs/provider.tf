terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=4.38.0"
      configuration_aliases = [google.deployment,google.shared-vpc]
    }
  }
  required_version = ">=1.2.4"
}
