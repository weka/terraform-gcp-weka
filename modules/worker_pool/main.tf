data "google_compute_network" "vnet" {
  name    = var.vpc_name
  project = var.network_project_id
}

data "google_project" "project" {
  project_id = var.project_id
}

data "google_project" "network_project" {
  project_id = var.network_project_id
}

resource "google_project_service" "servicenetworking" {
  project                    = var.network_project_id
  service                    = "servicenetworking.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service_identity" "servicenetworking_agent" {
  provider   = google-beta
  project    = var.network_project_id
  service    = "servicenetworking.googleapis.com"
  depends_on = [google_project_service.servicenetworking]
}

resource "google_project_iam_member" "servicenetworking_agent" {
  project    = var.network_project_id
  role       = "roles/servicenetworking.serviceAgent"
  member     = "serviceAccount:${google_project_service_identity.servicenetworking_agent.email}"
  depends_on = [google_project_service_identity.servicenetworking_agent]
}

resource "google_project_iam_member" "service_networking_network_proj" {
  role       = "roles/servicenetworking.serviceAgent"
  project    = var.network_project_id
  member     = "serviceAccount:service-${data.google_project.network_project.number}@service-networking.iam.gserviceaccount.com"
  depends_on = [google_project_service.servicenetworking]
}

resource "google_project_iam_member" "service_networking_main_proj" {
  role       = "roles/servicenetworking.serviceAgent"
  project    = var.project_id
  member     = "serviceAccount:service-${data.google_project.project.number}@service-networking.iam.gserviceaccount.com"
  depends_on = [google_project_service.servicenetworking]
}

resource "google_compute_global_address" "worker_range" {
  name          = "${var.prefix}-${var.cluster_name}-worker-range"
  project       = var.network_project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = var.worker_address
  prefix_length = var.worker_address_prefix_length
  network       = data.google_compute_network.vnet.id
  lifecycle {
    ignore_changes = [network]
  }
}

resource "google_service_networking_connection" "worker_pool_connection" {
  network                 = data.google_compute_network.vnet.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.worker_range.name]
  lifecycle {
    ignore_changes = [network]
  }
  depends_on = [google_project_service_identity.servicenetworking_agent, google_project_iam_member.servicenetworking_agent, google_service_networking_connection.worker_pool_connection, google_project_iam_member.service_networking_network_proj]
}

resource "google_compute_network_peering_routes_config" "service_networking_peering_config" {
  project = var.network_project_id
  peering = google_service_networking_connection.worker_pool_connection.peering
  network = var.vpc_name

  export_custom_routes = true
  import_custom_routes = true
  depends_on = [
    google_service_networking_connection.worker_pool_connection, google_project_service_identity.servicenetworking_agent, google_project_iam_member.servicenetworking_agent, google_project_iam_member.service_networking_network_proj
  ]
}

# Cloud Build Worker Pool
resource "google_cloudbuild_worker_pool" "pool" {
  name     = "${var.prefix}-${var.cluster_name}-worker-pool"
  project  = var.project_id
  location = var.region
  worker_config {
    disk_size_gb   = var.worker_disk_size
    machine_type   = var.worker_machine_type
    no_external_ip = true
  }
  network_config {
    peered_network = data.google_compute_network.vnet.id
  }
  lifecycle {
    ignore_changes = [network_config]
  }
  depends_on = [google_service_networking_connection.worker_pool_connection, google_project_service_identity.servicenetworking_agent, google_project_iam_member.service_networking_main_proj]
}
