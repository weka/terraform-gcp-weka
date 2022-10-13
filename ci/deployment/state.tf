terraform {
  backend "gcs" {
    bucket  = "weka-infra-backend"
    prefix  = "ci/state"
  }
  required_version = ">=1.2.4"
}
