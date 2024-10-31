locals {
  get_cluster_status_uri          = google_cloudfunctions2_function.status_function.service_config[0].uri
  resize_cluster_uri              = format("%s%s", google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri, "?action=resize")
  lb_url                          = trimsuffix(google_dns_record_set.record_a.name, ".")
  terminate_cluster_uri           = format("%s%s", google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri, "?action=terminate_cluster")
  weka_cluster_password_secret_id = google_secret_manager_secret.secret_weka_password.secret_id
  ips_type                        = local.assign_public_ip ? "accessConfigs[0].natIP" : "networkIP"
  functions_url = {
    progressing_status = { url = local.get_cluster_status_uri, body = { "type" : "progress" } }
    status             = { url = local.get_cluster_status_uri, body = { "type" : "status" } }
    resize             = { url = local.resize_cluster_uri, body = { "value" : 7 } }
    destroy            = { url = local.terminate_cluster_uri, body = { "name" : var.cluster_name } }
  }
}

output "functions_url" {
  value       = local.functions_url
  description = "Functions url and body for api request"
}

output "vm_username" {
  value       = var.vm_username
  description = "Provided as part of output for automated use of terraform, ssh user to weka cluster vm"
}

output "private_ssh_key" {
  value       = var.ssh_public_key == null ? local.ssh_private_key_path : null
  description = "private_ssh_key:  If 'ssh_public_key' is set to null, it will output the private ssh key location."
}

output "get_cluster_status_uri" {
  value       = local.get_cluster_status_uri
  description = "URL of status function"
}

output "resize_cluster_uri" {
  value       = local.resize_cluster_uri
  description = "URL of resize function"
}

output "terminate_cluster_uri" {
  value       = local.terminate_cluster_uri
  description = "URL of terminate function"
}

output "lb_url" {
  value       = local.lb_url
  description = "URL of LB"
}

output "backend_lb_ip" {
  value       = google_compute_forwarding_rule.google_compute_forwarding_rule.ip_address
  description = "The backend load balancer ip address."
}

output "cluster_name" {
  value       = var.cluster_name
  description = "The cluster name"
}

output "project_id" {
  value       = var.project_id
  description = "Project ID"
}

output "weka_cluster_admin_password_secret_id" {
  value       = local.weka_cluster_password_secret_id
  description = "Secret id of weka cluster admin password"
}

output "nfs_protocol_gateways_ips" {
  value       = var.nfs_protocol_gateways_number == 0 ? null : <<EOT
gcloud compute instances list --filter="name~'${module.nfs_protocol_gateways[0].gateways_name}'" --format "get(networkInterfaces[0].${local.ips_type})" --project ${var.project_id}
EOT
  description = "Ips of NFS protocol gateways"
}

output "smb_protocol_gateways_ips" {
  value       = var.smb_protocol_gateways_number == 0 ? null : <<EOT
gcloud compute instances list --filter="name~'${module.smb_protocol_gateways[0].gateways_name}'" --format "get(networkInterfaces[0].${local.ips_type})" --project ${var.project_id}
EOT
  description = "Ips of SMB protocol gateways"
}

output "s3_protocol_gateways_ips" {
  value       = var.s3_protocol_gateways_number == 0 ? null : <<EOT
gcloud compute instances list --filter="name~'${module.s3_protocol_gateways[0].gateways_name}'" --format "get(networkInterfaces[0].${local.ips_type})" --project ${var.project_id}
EOT
  description = "Ips of S3 protocol gateways"
}

output "cluster_helper_commands" {
  value = {
    get_status            = <<EOT
# for fetching cluster status pass: -d '{"type":"status"}'
curl -m 70 -X POST "${local.get_cluster_status_uri}" \
  -H "Authorization:bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type:application/json" -d '{"type":"progress"}'
EOT
    resize_cluster        = <<EOT
curl -m 70 -X POST "${local.resize_cluster_uri}" \
  -H "Authorization:bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type:application/json" \
  -d '{"value":ENTER_NEW_VALUE_HERE}'
EOT
    pre_terraform_destroy = <<EOT
# replace CLUSTER_NAME with the actual cluster name, as a confirmation of the destructive action
# this function needs to be executed prior to terraform destroy
curl -m 70 -X POST "${local.terminate_cluster_uri}" \
  -H "Authorization:bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type:application/json" \
  -d '{"name":"CLUSTER_NAME"}'
EOT
    get_password          = "gcloud secrets versions access latest --secret=${local.weka_cluster_password_secret_id}  --project ${var.project_id} --format='get(payload.data)' | base64 -d"
    get_backend_ips       = "gcloud compute instances list --filter='labels.weka_cluster_name=${var.cluster_name}' --format 'get(networkInterfaces[0].${local.ips_type})' --project ${var.project_id}"
  }
  description = "Useful commands and script to interact with weka cluster"
}

output "client_ips" {
  value       = var.clients_number > 0 ? module.clients[0].client_ips : []
  description = "If 'assign_public_ip' is set to true, it will output clients public ips, otherwise private ips."
}
