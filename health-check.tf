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
    group               = google_compute_instance_group.instance_group.id
  }
}

# forwarding rule
resource "google_compute_forwarding_rule" "google_compute_forwarding_rule" {
  name                  = "${var.prefix}-forwarding-rule"
  backend_service       = google_compute_region_backend_service.backend_service.id
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  all_ports             = true
  network               = "https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/${google_compute_network.vpc_network[0].name}"
  subnetwork            = "https://www.googleapis.com/compute/v1/projects/${var.project}/regions/${var.region}/subnetworks/${google_compute_subnetwork.subnetwork[0].name}"
}

# allow all access from health check ranges
resource "google_compute_firewall" "fw_hc" {
  name          = "${var.prefix}-fw-allow-hc"
  direction     = "INGRESS"
  network       = "https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/${google_compute_network.vpc_network[0].name}"
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "35.235.240.0/20"]
  allow {
    protocol = "tcp"
  }
  source_tags = ["allow-health-check"]
}

# allow communication within the subnet
resource "google_compute_firewall" "fw_ilb_to_backends" {
  name          = "${var.prefix}-fw-allow-ilb-to-backends"
  direction     = "INGRESS"
  network       = "https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/${google_compute_network.vpc_network[0].name}"
  source_ranges = [var.subnets[0]]
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}