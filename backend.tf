terraform {
  backend "gcs" {
    bucket = "wekaio-qa-infra-backend"
    prefix = "terrafrom/state-111"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>4.27.0"
      configuration_aliases = [google.main,google.deployment,google.shared-vpc]
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

provider "google" {
  alias   = "shared-vpc"
  project = var.host_project
  region  = var.region
}
