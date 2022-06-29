terraform {
  backend "gcs" {
    bucket = "weka-infra-backend"
    prefix = "terrafrom/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.27.0"
    }
  }
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

