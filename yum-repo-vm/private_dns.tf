locals {
  network_list = concat(formatlist(google_compute_network.vpc_network.id), [for v in data.google_compute_network.vpcs_ids: v.id ])
}

resource "google_dns_managed_zone" "private-zone" {
  name        = "weka-private-zone"
  dns_name    = "weka.private.net."
  project     = var.project
  description = "private dns weka.private.net"
  visibility  = "private"

  private_visibility_config {
    dynamic "networks" {
      for_each = local.network_list
       content {
         network_url = networks.value
       }
    }
  }
}

resource "google_dns_record_set" "record-a" {
  name         = "yum.${google_dns_managed_zone.private-zone.dns_name}"
  managed_zone = google_dns_managed_zone.private-zone.name
  project      = var.project
  type         = "A"
  ttl          = 120
  rrdatas      = [google_compute_instance.vm-repo.network_interface.0.network_ip]
}