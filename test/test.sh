#!/bin/bash

sudo yum install wget -y
wget https://github.com/tigrawap/goader/releases/download/v1.4.14/goader_linux_amd64
chmod +x goader_linux_amd64

#./goader_linux_amd64 --body-size 1M -wt 32 -rt 32 --max-requests=1000000 --url=/mnt/weka/NN/NN --mkdirs --show-progress=False
#./goader_linux_amd64 --body-size 4k -wt 128 -rt 128` or more complex `--requests-engine=meta --requests-ops=mknod,unlink,write,read,truncate,symlink,hardlink,stat,rename -wt=256
#cat vmnames | xargs -n1 -P32 -INN gcloud compute ssh --zone "us-east1-c" "NN" --project "my-demo-project-294621" goader ...`
#weka stats --node-ids=23 --show-internal --stat reactor.IDLE_TIME --interval 60
#weka stats realtime