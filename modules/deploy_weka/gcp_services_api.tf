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

# for google_compute_region_health_check
resource "google_project_service" "compute-api" {
  project = var.project
  service = "compute.googleapis.com"
  disable_on_destroy = false
  disable_dependent_services = false
}
