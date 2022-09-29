terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>4.38.0"
      configuration_aliases = [google.main,google.deployment]
    }
  }
  required_version = ">=1.3.1"
}


provider "google" {
  alias   = "main"
  project = var.project
  region  = var.region
}

provider "google" {
  alias   = "deployment"
  project = var.project
  region  = var.region
  credentials = module.create_service_account.output-sa-key
}