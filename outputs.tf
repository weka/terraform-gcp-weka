locals {
  get_cluster_status_uri          = google_cloudfunctions2_function.status_function.service_config[0].uri
  resize_cluster_uri              = format("%s%s", google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri, "?action=resize")
  lb_url                          = trimsuffix(google_dns_record_set.record_a.name, ".")
  terminate_cluster_uri           = format("%s%s", google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri, "?action=terminate_cluster")
  weka_cluster_password_secret_id = google_secret_manager_secret.secret_weka_password.secret_id
  protocol_gateways_ips_type      = var.assign_public_ip ? "accessConfigs[0].natIP" : "networkIP"
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

output "ssh_user" {
  value       = var.ssh_user
  description = "ssh user for weka cluster"
}

output "private_ssh_key" {
  value       = var.ssh_public_key == null ? local.ssh_private_key_path : null
  description = "private_ssh_key:  If 'ssh_public_key' is set to null, it will output the private ssh key location."
}

output "get_cluster_status_uri" {
  value = local.get_cluster_status_uri
}

output "resize_cluster_uri" {
  value = local.resize_cluster_uri
}

output "terminate_cluster_uri" {
  value = local.terminate_cluster_uri
}

output "lb_url" {
  value = local.lb_url
}

output "cluster_name" {
  value = var.cluster_name
}

output "project_id" {
  value = var.project_id
}

output "weka_cluster_password_secret_id" {
  value = local.weka_cluster_password_secret_id
}

output "nfs_protocol_gateways_ips" {
  value = var.nfs_protocol_gateways_number == 0 ? null : <<EOT
gcloud compute instances list --filter="name~'${module.nfs_protocol_gateways[0].gateways_name}'" --format "get(networkInterfaces[0].${local.protocol_gateways_ips_type})"
EOT
}

output "smb_protocol_gateways_ips" {
  value = var.smb_protocol_gateways_number == 0 ? null : <<EOT
gcloud compute instances list --filter="name~'${module.smb_protocol_gateways[0].gateways_name}'" --format "get(networkInterfaces[0].${local.protocol_gateways_ips_type})"
EOT
}

output "cluster_helper_commands" {
  value       = <<EOT
########################################## get cluster status ##########################################
curl -m 70 -X POST "${local.get_cluster_status_uri}" \
-H "Authorization:bearer $(gcloud auth print-identity-token)" \
-H "Content-Type:application/json" -d '{"type":"progress"}'
# for fetching cluster status pass: -d '{"type":"status"}'

########################################## resize cluster command ##########################################
curl -m 70 -X POST "${local.resize_cluster_uri}" \
-H "Authorization:bearer $(gcloud auth print-identity-token)" \
-H "Content-Type:application/json" \
-d '{"value":ENTER_NEW_VALUE_HERE}'


########################################## pre-terraform destroy, cluster terminate function ################

# replace CLUSTER_NAME with the actual cluster name, as a confirmation of the destructive action
# this function needs to be executed prior to terraform destroy
curl -m 70 -X POST "${local.terminate_cluster_uri}" \
-H "Authorization:bearer $(gcloud auth print-identity-token)" \
-H "Content-Type:application/json" \
-d '{"name":"${var.cluster_name}"}'


################################# get weka password secret login ############################################

gcloud secrets versions access 1 --secret=${local.weka_cluster_password_secret_id}  --project ${var.project_id} --format='get(payload.data)' | base64 -d

EOT
  description = "Useful commands and script to interact with weka cluster"
}

output "client_ips" {
  value       = var.clients_number > 0 ? module.clients[0].client_ips : []
  description = "If 'assign_public_ip' is set to true, it will output clients public ips, otherwise private ips."
}
