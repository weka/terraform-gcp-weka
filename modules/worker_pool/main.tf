data "google_compute_network" "this" {
  name = var.vpc_name
}

data "google_compute_network" "worker_pool_network" {
  count = var.set_worker_pool_network_peering ? 1 : 0
  name  = var.worker_pool_network
}
# ================ worker_pool ======================= #

resource "google_project_iam_binding" "servicenetworking_binding" {
  role    = "roles/compute.networkAdmin"
  members = ["serviceAccount:${var.sa_email}"]
  project = var.project_id
  lifecycle {
    ignore_changes = [members]
  }
}

resource "google_project_iam_binding" "servicenetworking_admin_binding" {
  role    = "roles/servicenetworking.networksAdmin"
  members = ["serviceAccount:${var.sa_email}"]
  project = var.project_id
  lifecycle {
    ignore_changes = [members]
  }
}

resource "google_project_iam_binding" "worker_pool_binding" {
  role    = "roles/cloudbuild.workerPoolOwner"
  members = ["serviceAccount:${var.sa_email}"]
  project = var.project_id
  lifecycle {
    ignore_changes = [members]
  }
}

resource "google_project_service" "servicenetworking" {
  service                    = "servicenetworking.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = true
  depends_on                 = [google_project_iam_binding.servicenetworking_binding, google_project_iam_binding.worker_pool_binding, google_project_iam_binding.servicenetworking_admin_binding]
}

resource "null_resource" "wait_service_enable" {
  count = var.worker_pool_name == "" ? 1 : 0
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<EOT
    echo "Waiting for service to enable..."
    sleep 120
    EOT
  }
  depends_on = [google_project_service.servicenetworking]
}

resource "google_compute_global_address" "worker_range_ip" {
  count         = var.worker_pool_name == "" ? 1 : 0
  name          = "${var.prefix}-${var.cluster_name}-worker-pool-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.this.id
  lifecycle {
    ignore_changes = [network]
  }
  depends_on = [null_resource.wait_service_enable, google_project_service.servicenetworking, google_project_iam_binding.servicenetworking_binding, google_project_iam_binding.worker_pool_binding]
}

resource "google_service_networking_connection" "worker_pool_conn" {
  count                   = var.worker_pool_name == "" ? 1 : 0
  network                 = data.google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.worker_range_ip[0].name]
  lifecycle {
    ignore_changes = [network]
  }
  depends_on = [null_resource.wait_service_enable, google_compute_global_address.worker_range_ip]
}

resource "google_cloudbuild_worker_pool" "worker_pool" {
  count    = var.worker_pool_name == "" ? 1 : 0
  name     = "${var.prefix}-${var.cluster_name}-worker-pool"
  location = var.region
  worker_config {
    disk_size_gb   = var.worker_disk_size
    machine_type   = var.worker_machine_type
    no_external_ip = true
  }
  network_config {
    peered_network = data.google_compute_network.this.id
  }
  lifecycle {
    ignore_changes = [network_config]
  }
  depends_on = [null_resource.wait_service_enable, google_service_networking_connection.worker_pool_conn]
}

# ============ set peering ==================== #
resource "google_compute_network_peering" "peering_vpc" {
  count        = var.set_worker_pool_network_peering ? 1 : 0
  name         = "${var.vpc_name}-peering-to-${var.worker_pool_name}"
  network      = data.google_compute_network.this.self_link
  peer_network = data.google_compute_network.worker_pool_network[0].self_link
  depends_on   = [google_project_iam_binding.servicenetworking_binding, google_project_iam_binding.worker_pool_binding]
}

# ============ set peering ==================== #
resource "google_compute_network_peering" "peering_worker" {
  count        = var.set_worker_pool_network_peering ? 1 : 0
  name         = "${var.worker_pool_name}-peering-to-${var.vpc_name}"
  network      = data.google_compute_network.worker_pool_network[0].self_link
  peer_network = data.google_compute_network.this.self_link
  depends_on   = [google_project_iam_binding.servicenetworking_binding, google_project_iam_binding.worker_pool_binding]
}
