resource "google_project_service" "appengine" {
  project = var.project
  service = "appengine.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "project-function-api" {
  project = var.project
  service = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}

resource "google_project_service" "cloud-build-api" {
  project = var.project
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}

resource "google_project_service" "service-usage-api" {
  project = var.project
  service = "serviceusage.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}

resource "google_project_service" "service-scheduler-api" {
  project = var.project
  service = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}
