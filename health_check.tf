# health check
resource "google_compute_region_health_check" "health_check" {
  name                = "${var.prefix}-${var.cluster_name}-health-check"
  region              = var.region
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
  health_checks         = [google_compute_region_health_check.health_check.id]
  network               = data.google_compute_network.this[0].self_link
  backend {
    group = google_compute_instance_group.this.self_link
  }
  depends_on = [module.network, module.vpc_peering, google_compute_instance_group.this]
}

# forwarding rule
resource "google_compute_forwarding_rule" "google_compute_forwarding_rule" {
  name                  = "${var.prefix}-${var.cluster_name}-forwarding-rule"
  backend_service       = google_compute_region_backend_service.backend_service.id
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  all_ports             = true
  network               = data.google_compute_network.this[0].self_link
  subnetwork            = data.google_compute_subnetwork.this[0].self_link
  lifecycle {
    ignore_changes = [network, subnetwork]
  }
  depends_on = [module.network, module.vpc_peering, data.google_compute_network.this]
}

resource "google_dns_record_set" "record_a" {
  name         = "${var.cluster_name}.${local.private_dns_name}"
  managed_zone = local.private_zone_name
  type         = "A"
  ttl          = 120
  rrdatas      = [google_compute_forwarding_rule.google_compute_forwarding_rule.ip_address]
  depends_on   = [google_compute_region_backend_service.backend_service, google_compute_forwarding_rule.google_compute_forwarding_rule]
}

# =================== ui lb ===============================
# health check
resource "google_compute_region_health_check" "ui_check" {
  name                = "${var.prefix}-${var.cluster_name}-ui-check"
  region              = var.region
  timeout_sec         = 1
  check_interval_sec  = 1
  healthy_threshold   = 4
  unhealthy_threshold = 5
  http_health_check {
    port         = "14000"
    request_path = "/api/v2/ui/healthcheck"
  }
  depends_on = [module.network]
}


# backend service
resource "google_compute_region_backend_service" "ui_backend_service" {
  name                  = "${var.prefix}-${var.cluster_name}-ui-lb-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_region_health_check.ui_check.id]
  network               = data.google_compute_network.this[0].self_link
  backend {
    group = google_compute_instance_group.this.self_link
  }
  depends_on = [module.network, module.vpc_peering, google_compute_instance_group.this]
}

# forwarding rule
resource "google_compute_forwarding_rule" "ui_forwarding_rule" {
  name                  = "${var.prefix}-${var.cluster_name}-ui-forwarding-rule"
  backend_service       = google_compute_region_backend_service.ui_backend_service.id
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  all_ports             = true
  network               = data.google_compute_network.this[0].self_link
  subnetwork            = data.google_compute_subnetwork.this[0].self_link
  lifecycle {
    ignore_changes = [network, subnetwork]
  }
  depends_on = [module.network, module.vpc_peering]
}

resource "google_dns_record_set" "ui_record_a" {
  name         = "ui-${var.cluster_name}.${local.private_dns_name}"
  managed_zone = local.private_zone_name
  type         = "A"
  ttl          = 120
  rrdatas      = [google_compute_forwarding_rule.ui_forwarding_rule.ip_address]
  depends_on   = [google_compute_region_backend_service.ui_backend_service, google_compute_forwarding_rule.ui_forwarding_rule]
}
