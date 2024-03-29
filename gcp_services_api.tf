resource "google_project_service" "project_function_api" {
  service                    = "cloudfunctions.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "cloud_build_api" {
  service                    = "cloudbuild.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "run_api" {
  service                    = "run.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "artifactregistry_api" {
  service                    = "artifactregistry.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "service_usage_api" {

  service                    = "serviceusage.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "service_scheduler_api" {
  service                    = "cloudscheduler.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

# for google_compute_region_health_check
resource "google_project_service" "compute_api" {
  service                    = "compute.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}
