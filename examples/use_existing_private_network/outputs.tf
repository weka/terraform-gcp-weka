output "output" {
  value = <<EOT
########################################## resize cluster command ##########################################
curl -m 70 -X POST ${module.deploy_weka.output-resize-cloud-functions} \
-H "Authorization:bearer $(gcloud auth print-identity-token)" \
-H "Content-Type:application/json" \
-d '{"value":ENTER_NEW_VALUE_HERE}'

########################################## join new client script ##########################################
#!/bin/bash

lb_url="${trimsuffix(module.deploy_weka.output-lb-dns, ".")}"
curl "$lb_url:14000/dist/v1/install" | sh

FILESYSTEM_NAME=default # replace with a different filesystem at need
MOUNT_POINT=/mnt/weka # replace with a different mount point at need

mkdir -p $MOUNT_POINT
mount -t wekafs "$lb_url/$FILESYSTEM_NAME" $MOUNT_POINT
EOT
}