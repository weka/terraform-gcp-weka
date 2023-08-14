locals {
  get_cluster_status_uri = google_cloudfunctions2_function.status_function.service_config[0].uri
  resize_cluster_uri = format("%s%s", google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri, "?action=resize")
  lb_url = trimsuffix(google_dns_record_set.record-a.name, ".")
  terminate_cluster_uri = format("%s%s", google_cloudfunctions2_function.cloud_internal_function.service_config[0].uri, "?action=terminate_cluster")
  weka_cluster_password_secret_id = google_secret_manager_secret.secret_weka_password.secret_id
}

output "ssh_user" {
  value = "weka"
  description = "ssh user for weka cluster"
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

output "cluster_helper_commands" {
  value = <<EOT
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

########################################## join new client script ##########################################
#!/bin/bash

lb_url="${local.lb_url}"
curl "$lb_url:14000/dist/v1/install" | sh

FILESYSTEM_NAME=default # replace with a different filesystem at need
MOUNT_POINT=/mnt/weka # replace with a different mount point at need

mkdir -p $MOUNT_POINT
mount -t wekafs "$lb_url/$FILESYSTEM_NAME" $MOUNT_POINT


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
