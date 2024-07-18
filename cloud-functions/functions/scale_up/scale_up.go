package scale_up

import (
	"context"
	"fmt"
	"strings"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"google.golang.org/protobuf/proto"
)

func getInstanceTemplateByName(ctx context.Context, project, templateName string) (*computepb.InstanceTemplate, error) {
	instanceTemplatesClient, err := compute.NewInstanceTemplatesRESTClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("NewInstanceTemplatesRESTClient: %w", err)
	}
	defer instanceTemplatesClient.Close()

	req := &computepb.GetInstanceTemplateRequest{
		Project:          project,
		InstanceTemplate: templateName,
	}

	return instanceTemplatesClient.Get(ctx, req)
}

func getInstanceTemplate(ctx context.Context, project, template string) (*computepb.InstanceTemplate, error) {
	templateParts := strings.Split(template, "/")
	templateName := templateParts[len(templateParts)-1]

	return getInstanceTemplateByName(ctx, project, templateName)
}

func CreateBackendInstance(ctx context.Context, project, zone, template, instanceName, yumRepoServer, proxyUrl, functionRootUrl string) (err error) {
	instancesClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed to create instances client")
		return
	}
	defer instancesClient.Close()

	startUpScript := `
	#!/bin/bash
	set -ex
	instance_name=%s
	function_url=%s
	yum_repo_server=%s
	proxy_url=%s

	if [ "$proxy_url" ] ; then
		sudo sed -i "/distroverpkg=centos-release/a proxy=$proxy_url" /etc/yum.conf
	fi

	if [ "$yum_repo_server" ] ; then
		mkdir /tmp/yum.repos.d
		mv /etc/yum.repos.d/*.repo /tmp/yum.repos.d/

		cat >/etc/yum.repos.d/local.repo <<EOL
	[localrepo-base]
	name=RockyLinux Base
	baseurl=$yum_repo_server/baseos/
	gpgcheck=0
	enabled=1
	[localrepo-appstream]
	name=RockyLinux Base
	baseurl=$yum_repo_server/appstream/
	gpgcheck=0
	enabled=1
	EOL
	fi

	os=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
	if [[ "$os" = *"Rocky"* ]]; then
		sudo yum install -y bc
		sudo yum install -y perl-interpreter
		if [ "$yum_repo_server" ]; then
			yum -y install $yum_repo_server/baseos/Packages/k/kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
			yum -y install wget
		else
			sudo curl https://dl.rockylinux.org/vault/rocky/8.9/Devel/x86_64/os/Packages/k/kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm --output kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
			sudo rpm -i kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
		fi

	fi

	sudo yum install -y jq || (echo "Failed to install jq" && exit 1)

	gcloud config set functions/gen2 true

	self_deleting() {
		echo "deploy failed, self deleting..."
		zone=$(curl -X GET http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')
		gcloud compute instances update $instance_name --no-deletion-protection --zone=$zone
		gcloud --quiet compute instances delete $instance_name --zone=$zone
	}

	echo "Generating weka deploy script..."
	curl "$function_url?action=deploy" --fail -H "Authorization:bearer $(gcloud auth print-identity-token)" -d "{\"name\": \"$instance_name\"}" > /tmp/deploy.sh
	chmod +x /tmp/deploy.sh
	echo "Running weka deploy script..."
	(/tmp/deploy.sh 2>&1 | tee /tmp/weka_deploy.log) || self_deleting || shutdown -P
	`
	startUpScript = fmt.Sprintf(startUpScript, instanceName, functionRootUrl, yumRepoServer, proxyUrl)
	startUpScript = dedent.Dedent(startUpScript)

	instanceTemplate, err := getInstanceTemplate(ctx, project, template)
	if err != nil {
		log.Error().Msgf("Failed to get instance template (project=%s, template=%s): %s", project, template, err)
		return
	}

	items := []*computepb.Items{
		{
			Key:   proto.String("startup-script"),
			Value: &startUpScript,
		},
	}

	for _, item := range instanceTemplate.Properties.Metadata.Items {
		items = append(items, &computepb.Items{
			Key:   item.Key,
			Value: item.Value,
		})
	}

	req := &computepb.InsertInstanceRequest{
		Project: project,
		Zone:    zone,
		InstanceResource: &computepb.Instance{
			Name: proto.String(instanceName),
			Metadata: &computepb.Metadata{
				Items: items,
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

func CreateNFSInstance(ctx context.Context, project, zone, templateName, instanceName, yumRepoServer, proxyUrl, functionRootUrl string) (err error) {
	instancesClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed to create instances client")
		return
	}
	defer instancesClient.Close()

	instanceTemplate, err := getInstanceTemplateByName(ctx, project, templateName)
	if err != nil {
		log.Error().Msgf("Failed to get instance template (project=%s, template=%s): %s", project, templateName, err)
		return
	}

	req := &computepb.InsertInstanceRequest{
		Project: project,
		Zone:    zone,
		InstanceResource: &computepb.Instance{
			Name: proto.String(instanceName),
		},
		SourceInstanceTemplate: instanceTemplate.SelfLink,
	}

	_, err = instancesClient.Insert(ctx, req)
	if err != nil {
		log.Error().Msgf("Instance creation failed: %s", err)
	}
	return
}
