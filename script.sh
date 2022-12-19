cluster_creation_str="weka cluster create"
for (( i=0; i<$HOSTS_NUM; i++ )); do
    cluster_creation_str="$cluster_creation_str weka-$i"
done
cluster_creation_str="$cluster_creation_str --host-ips "
for (( i=0; i<$HOSTS_NUM; i++ )); do
    cluster_creation_str="$cluster_creation_str${IPS[$i*$NICS_NUM]},"
done
cluster_creation_str=${cluster_creation_str::-1}
eval "$cluster_creation_str --admin-password $ADMIN_PASSWORD"

weka user login "$ADMIN_USERNAME" "$ADMIN_PASSWORD"

sleep 15s
cores_num=`expr $NICS_NUM - 1`
for (( i=0; i<$HOSTS_NUM; i++ )); do weka cluster host cores $i $cores_num --frontend-dedicated-cores 1 --drives-dedicated-cores 1 ;done
for (( i=0; i<$HOSTS_NUM; i++ )); do weka cluster host dedicate $i on ; done
sleep 15s

for (( i=1; i<$NICS_NUM; i++ )); do
    for (( j=0; j<$HOSTS_NUM; j++ )); do
        weka cluster host net add $j "eth$i" --ips ${IPS[$NICS_NUM*$j + $i]} --gateway ${GWS[$i]}
    done
done

sleep 15s
for (( i=0; i<$HOSTS_NUM; i++ )); do
    for (( j=1; j<=$NVMES_NUM; j++ )); do
        weka cluster drive add $i "/dev/nvme0n$j";
    done
done
sleep 15s
weka cluster hot-spare 1
sleep 15s
weka cluster update --cluster-name="$CLUSTER_NAME"
sleep 15s
weka cluster host activate
sleep 15s
weka cluster host apply --all --force
sleep 30s
weka cluster start-io