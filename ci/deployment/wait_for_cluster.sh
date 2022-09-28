#!/bin/bash

vms=$(gcloud compute instance-groups list-instances weka-poc-instance-group --zone europe-west4-a | sed '1d' | wc -l)
count=1
expected_vms_number="$1"
timeout="$2"
while [ $vms -lt "$expected_vms_number" ] && [ $count -le "$timeout" ]
do
  echo "weka cluster isn't ready yet, going to sleep for 1M"
  sleep 60
  vms=$(gcloud compute instance-groups list-instances weka-poc-instance-group --zone europe-west4-a | sed '1d' | wc -l)
  count=$(( $count + 1 ))
done

if [ $count -gt "$timeout" ]; then
	exit 1
fi
