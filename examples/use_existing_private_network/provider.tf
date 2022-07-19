terraform {
  backend "gcs" {
    bucket = "xxx"
    prefix = "terrafrom/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>4.27.0"
      configuration_aliases = [google.main,google.deployment]
    }
  }
  required_version = ">=1.2.4"
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
