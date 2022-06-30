# health check
resource "google_compute_region_health_check" "health_check" {
  name                = "${var.prefix}-${var.cluster_name}-health-check"
  region = var.region
  timeout_sec         = 1
  check_interval_sec  = 1
  healthy_threshold   = 4
  unhealthy_threshold = 5
  http_health_check {
    port         = "14000"
    request_path = "/api/v2/healthcheck"
  }
}


# backend service
resource "google_compute_region_backend_service" "backend_service" {
  name                  = "${var.prefix}-${var.cluster_name}-lb-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [ google_compute_region_health_check.health_check.id]
  backend {
    group               = google_compute_instance_group.instance_group.self_link
  }

  depends_on = [google_cloudfunctions_function.deploy_function, google_cloudfunctions_function.bunch_function]
}

# forwarding rule
resource "google_compute_forwarding_rule" "google_compute_forwarding_rule" {
  name                  = "${var.prefix}-${var.cluster_name}-forwarding-rule"
  backend_service       = google_compute_region_backend_service.backend_service.id
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  all_ports             = true
  network               = "https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/${var.vpcs[0]}"
  subnetwork            = "https://www.googleapis.com/compute/v1/projects/${var.project}/regions/${var.region}/subnetworks/${var.subnets_name[0]}"
}
