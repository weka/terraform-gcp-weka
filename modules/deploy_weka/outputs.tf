output "output-lb-dns" {
  value = google_dns_record_set.record-a.name
}

output "cluster_helpers_commands" {
  value = <<EOT
########################################## resize cluster command ##########################################
curl -m 70 -X POST ${google_cloudfunctions_function.resize_function.https_trigger_url} \
-H "Authorization:bearer $(gcloud auth print-identity-token)" \
-H "Content-Type:application/json" \
-d '{"value":ENTER_NEW_VALUE_HERE}'

########################################## join new client script ##########################################
#!/bin/bash

lb_url="${trimsuffix(google_dns_record_set.record-a.name, ".")}"
curl "$lb_url:14000/dist/v1/install" | sh

FILESYSTEM_NAME=default # replace with a different filesystem at need
MOUNT_POINT=/mnt/weka # replace with a different mount point at need

mkdir -p $MOUNT_POINT
mount -t wekafs "$lb_url/$FILESYSTEM_NAME" $MOUNT_POINT


########################################## pre-terraform destroy, cluster terminate function ################




################################# get weka password secret login ############################################

gcloud secrets versions access 1 --secret=${google_secret_manager_secret.secret_weka_password.secret_id}  --project ${var.project} --format='get(payload.data)' | base64 -d

EOT
}
