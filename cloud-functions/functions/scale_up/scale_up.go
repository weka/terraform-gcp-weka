package scale_up

import (
	"context"
	"fmt"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"google.golang.org/protobuf/proto"
)

func CreateInstance(ctx context.Context, project, zone, template, instanceName, yumRepoServer, functionRootUrl string) (err error) {
	instancesClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer instancesClient.Close()

	startUpScript := `
	#!/bin/bash
	instance_name=%s
	function_url=%s
	yum_repo_server=%s
	
	if [ "$yum_repo_server" ] ; then
		mkdir /tmp/yum.repos.d
		mv /etc/yum.repos.d/*.repo /tmp/yum.repos.d/

		cat >/etc/yum.repos.d/local.repo <<EOL
	[local]
	name=Centos Base
	baseurl=$yum_repo_server
	enabled=1
	gpgcheck=0
	EOL
	fi

	sudo yum install -y jq  

	gcloud config set functions/gen2 true

	self_deleting() {
		echo "deploy failed, self deleting..."
		zone=$(curl -X GET http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')
		gcloud compute instances update $instance_name --no-deletion-protection --zone=$zone
		gcloud --quiet compute instances delete $instance_name --zone=$zone
	}

	curl "$function_url?action=deploy" --fail -H "Authorization:bearer $(gcloud auth print-identity-token)" -d "{\"vm\": \"$instance_name\"}" > /tmp/deploy.sh
	chmod +x /tmp/deploy.sh
	(/tmp/deploy.sh 2>&1 | tee /tmp/weka_deploy.log) || self_deleting || shutdown -P
	`
	startUpScript = fmt.Sprintf(startUpScript, instanceName, functionRootUrl, yumRepoServer)
	startUpScript = dedent.Dedent(startUpScript)

	req := &computepb.InsertInstanceRequest{
		Project: project,
		Zone:    zone,
		InstanceResource: &computepb.Instance{
			Name: proto.String(instanceName),
			Metadata: &computepb.Metadata{
				Items: []*computepb.Items{
					{
						Key:   proto.String("startup-script"),
						Value: &startUpScript,
					},
				},
			},
		},
		SourceInstanceTemplate: &template,
	}

	_, err = instancesClient.Insert(ctx, req)
	if err != nil {
		log.Error().Msgf("Instance creation failed: %s", err)
		return
	}

	return
}
