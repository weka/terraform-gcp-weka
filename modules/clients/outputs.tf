output "client_ips" {
  value = var.assign_public_ip ? google_compute_instance.this.*.network_interface.0.access_config.0.nat_ip : google_compute_instance.this.*.network_interface.0.network_ip
}
