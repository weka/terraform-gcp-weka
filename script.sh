#!/bin/bash

cluster_creation_str="weka cluster create"
for (( i=0; i<$HOSTS_NUM; i++ )); do
    cluster_creation_str="$cluster_creation_str weka-$i"
done
cluster_creation_str="$cluster_creation_str --host-ips "
for (( i=0; i<$HOSTS_NUM; i++ )); do
    cluster_creation_str="$cluster_creation_str${IPS[$i*4]},"
done
cluster_creation_str=${cluster_creation_str::-1}
eval "$cluster_creation_str"

sleep 15s
cores_num=`expr $GWS_NUM - 1`
for (( i=0; i<$HOSTS_NUM; i++ )); do weka cluster host cores $i $cores_num --frontend-dedicated-cores 1 --drives-dedicated-cores 1 ;done
for (( i=0; i<$HOSTS_NUM; i++ )); do weka cluster host dedicate $i on ; done
sleep 15s

for (( i=1; i<$GWS_NUM; i++ )); do
    for (( j=0; j<$HOSTS_NUM; j++ )); do
        weka cluster host net add $j "eth$i" --ips ${IPS[4*$j + $i]} --gateway ${GWS[$i]}
    done
done

sleep 15s
for (( i=0; i<$HOSTS_NUM; i++ )); do
    for (( j=0; i<$NVMES_NUM; j++ )); do
        weka cluster drive add $i "/dev/nvme0n$j";
    done
done
sleep 15s
weka cluster update --data-drives=4 --parity-drives=2
sleep 5s
weka cluster hot-spare 1
sleep 15s
weka cluster update --cluster-name="$CLUSTER_NAME"
sleep 15s
weka cluster host activate
sleep 15s
weka cluster host apply --all --force