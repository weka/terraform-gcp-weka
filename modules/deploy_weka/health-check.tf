# health check
resource "google_compute_region_health_check" "health_check" {
  name                = "${var.prefix}-${var.cluster_name}-health-check"
  region              = lookup(var.load_balancer_region_map, var.region, var.region)
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
  region                = lookup(var.load_balancer_region_map, var.region, var.region)
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [ google_compute_region_health_check.health_check.id]
  backend {
    group               = google_compute_instance_group.instance_group.self_link
  }
  depends_on = [google_compute_instance_group.instance_group]
}

# forwarding rule
resource "google_compute_forwarding_rule" "google_compute_forwarding_rule" {
  name                  = "${var.prefix}-${var.cluster_name}-forwarding-rule"
  backend_service       = google_compute_region_backend_service.backend_service.id
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  all_ports             = true
  network               = data.google_compute_network.vpc_list_ids[0].self_link
  subnetwork            = data.google_compute_subnetwork.subnets_list_ids[0].self_link
  lifecycle {
    ignore_changes = [network, subnetwork]
  }
}

resource "google_dns_record_set" "record-a" {
  name         = "${var.cluster_name}.${var.private_dns_name}"
  managed_zone = var.private_dns_zone
  project      = var.project
  type         = "A"
  ttl          = 120
  rrdatas      = [google_compute_forwarding_rule.google_compute_forwarding_rule.ip_address]
  depends_on   = [google_compute_region_backend_service.backend_service,google_compute_forwarding_rule.google_compute_forwarding_rule]
}

# =================== ui lb ===============================
# health check
resource "google_compute_region_health_check" "ui_check" {
  name                = "${var.prefix}-${var.cluster_name}-ui-check"
  region              = lookup(var.load_balancer_region_map, var.region, var.region)
  timeout_sec         = 1
  check_interval_sec  = 1
  healthy_threshold   = 4
  unhealthy_threshold = 5
  http_health_check {
    port         = "14000"
    request_path = "/api/v2/ui/healthcheck"
  }
}


# backend service
resource "google_compute_region_backend_service" "ui_backend_service" {
  name                  = "${var.prefix}-${var.cluster_name}-ui-lb-backend"
  region                = lookup(var.load_balancer_region_map, var.region, var.region)
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_region_health_check.ui_check.id]
  backend {
    group               = google_compute_instance_group.instance_group.self_link
  }
  depends_on = [google_compute_instance_group.instance_group]
}

# forwarding rule
resource "google_compute_forwarding_rule" "ui_forwarding_rule" {
  name                  = "${var.prefix}-${var.cluster_name}-ui-forwarding-rule"
  backend_service       = google_compute_region_backend_service.ui_backend_service.id
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  all_ports             = true
  network               = data.google_compute_network.vpc_list_ids[0].self_link
  subnetwork            = data.google_compute_subnetwork.subnets_list_ids[0].self_link
  lifecycle {
    ignore_changes = [network, subnetwork]
  }
}

resource "google_dns_record_set" "ui-record-a" {
  name         = "ui-${var.cluster_name}.${var.private_dns_name}"
  managed_zone = var.private_dns_zone
  project      = var.project
  type         = "A"
  ttl          = 120
  rrdatas      = [google_compute_forwarding_rule.ui_forwarding_rule.ip_address]
  depends_on   = [google_compute_region_backend_service.ui_backend_service,google_compute_forwarding_rule.ui_forwarding_rule]
}
