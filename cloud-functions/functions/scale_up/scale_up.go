package scale_up

import (
	"context"
	"fmt"
	"strings"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"cloud.google.com/go/storage"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/lib/jrpc"
	"github.com/weka/go-cloud-lib/lib/weka"
	"github.com/weka/go-cloud-lib/protocol"
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

func CreateBackendInstance(ctx context.Context, project, zone, template, instanceName, yumRepositoryBaseosUrl, yumRepositoryAppstreamUrl, proxyUrl, functionRootUrl string) (err error) {
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
	yumRepositoryBaseosUrl=%s
	yumRepositoryAppstreamUrl=%s
	proxy_url=%s

	if [ "$proxy_url" ] ; then
		sudo sed -i "/distroverpkg=centos-release/a proxy=$proxy_url" /etc/yum.conf
	fi

	if [ "$yumRepositoryBaseosUrl" ] ; then
		mkdir /tmp/yum.repos.d
		mv /etc/yum.repos.d/*.repo /tmp/yum.repos.d/

		cat >/etc/yum.repos.d/local.repo <<EOL
	[localrepo-base]
	name=RockyLinux BaseOs
	baseurl=$yumRepositoryBaseosUrl
	gpgcheck=0
	enabled=1
	module_hotfixes=1
	[localrepo-appstream]
	name=RockyLinux AppStream
	baseurl=$yumRepositoryAppstreamUrl
	gpgcheck=0
	enabled=1
	module_hotfixes=1
	EOL
	fi

	os=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
	if [[ "$os" = *"Rocky"* ]]; then
		yum install -y kernel-devel-$(uname -r)
	fi

	yum install -y jq || (echo "Failed to install jq" && exit 1)

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
	startUpScript = fmt.Sprintf(startUpScript, instanceName, functionRootUrl, yumRepositoryBaseosUrl, yumRepositoryAppstreamUrl, proxyUrl)
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

func CreateNFSInstance(ctx context.Context, project, zone, templateName, instanceName, yumRepositoryBaseosUrl, yumRepositoryAppstreamUrl, proxyUrl, functionRootUrl string) (err error) {
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

func MigrateExistingNFSInstances(
	ctx context.Context, project, zone, bucket, nfsObject, gatewaysName, defaultIgName, nfsInstanceGroup, backendsInstanceGroup, usernameId, passwordId, adminPasswordId string,
) (migratedInstanceNames []string, err error) {
	log.Info().Msg("Migrating existing NFS instances to state")

	jpool, err := common.GetWekaJrpcPool(ctx, project, zone, backendsInstanceGroup, usernameId, passwordId, adminPasswordId)
	if err != nil {
		return
	}

	interfaceGroups := weka.InterfaceGroupListResponse{}
	err = jpool.Call(weka.JrpcInterfaceGroupList, struct{}{}, &interfaceGroups)
	if err != nil {
		err = fmt.Errorf("failed to get interface groups from weka jrpc: %w", err)
		return
	}

	var interfaceGroup *weka.InterfaceGroup

	if len(interfaceGroups) == 0 {
		log.Info().Msg("No NFS interface groups configured")
	} else {
		log.Info().Msgf("More than one NFS interface group configured, picking default one: %s", defaultIgName)
		for _, ig := range interfaceGroups {
			if ig.Name == defaultIgName {
				interfaceGroup = &ig
				break
			}
		}
		if interfaceGroup == nil {
			err = fmt.Errorf("default NFS interface group with name %s not found", defaultIgName)
			return
		}
	}

	// get NFS state
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := common.LockBucket(ctx, client, bucket, nfsObject)
	defer common.UnlockBucket(ctx, client, bucket, nfsObject, id)

	stateHandler := client.Bucket(bucket).Object(nfsObject)
	nfsState, err := common.ReadState(stateHandler, ctx)
	if err != nil {
		return
	}

	// put existing instances in state (if any)
	if interfaceGroup != nil {
		gwVms, err1 := getProtocolGwInstancesFromInterfaceGroup(ctx, jpool, interfaceGroup)
		if err1 != nil {
			err = fmt.Errorf("failed to get protocol gw instances from interface group: %w", err1)
			return
		}

		if interfaceGroup.Status == "OK" {
			nfsState.Clusterized = true
		} else {
			nfsState.Instances = append(nfsState.Instances, gwVms...)
		}

		err1 = addNfsInstancesToGroup(ctx, project, zone, nfsInstanceGroup, gwVms)
		if err1 != nil {
			err = fmt.Errorf("failed to add gw instances to group: %w", err1)
			return
		}

		labels := map[string]string{
			common.WekaProtocolGwLabelKey:   gatewaysName,
			common.NfsInterfaceGroupPortKey: common.NfsInterfaceGroupPortValue,
		}
		err1 = setLabelsOnNfsInstances(ctx, project, zone, gwVms, labels)
		if err1 != nil {
			err = fmt.Errorf("failed to set labels on gw instances: %w", err1)
			return
		}

		migratedInstanceNames = common.GetInstancesNames(gwVms)
		log.Info().Msgf("Migrated %d existing NFS instances to state: %v", len(gwVms), migratedInstanceNames)
	}

	nfsState.NfsInstancesMigrated = true
	err = common.RetryWriteState(stateHandler, ctx, nfsState)
	return
}

func addNfsInstancesToGroup(ctx context.Context, project, zone, instanceGroup string, vms []protocol.Vm) (err error) {
	log.Info().Msgf("Adding %d NFS instances to group %s", len(vms), instanceGroup)

	instanceNames := common.GetInstancesNames(vms)
	err = common.AddInstancesToGroup(ctx, project, zone, instanceGroup, instanceNames)
	if err != nil {
		log.Error().Err(err).Strs("instances", instanceNames).Str("group", instanceGroup).Msg("Failed to add instances to group")
		return
	}
	log.Info().Msgf("Added %d existing NFS instances to group: %s", len(vms), instanceGroup)
	return
}

func setLabelsOnNfsInstances(ctx context.Context, project, zone string, vms []protocol.Vm, labels map[string]string) (err error) {
	log.Info().Msgf("Setting labels on %d gw instances", len(vms))

	var errs []error
	for _, vm := range vms {
		err := common.AddLabelsOnInstance(ctx, project, zone, vm.Name, labels)
		if err != nil {
			errs = append(errs, err)
			log.Error().Err(err).Msgf("Failed to set labels on gw instance: %s", vm.Name)
		} else {
			log.Info().Msgf("Set labels on gw instance: %s", vm.Name)
		}
	}
	if len(errs) > 0 {
		err = fmt.Errorf("failed to set labels on gw instances: %v", errs)
	}
	return
}

func getProtocolGwInstancesFromInterfaceGroup(ctx context.Context, jpool *jrpc.Pool, interfaceGroup *weka.InterfaceGroup) (vms []protocol.Vm, err error) {
	hosts := weka.HostListResponse{}
	err = jpool.Call(weka.JrpcHostList, struct{}{}, &hosts)
	if err != nil {
		err = fmt.Errorf("failed to get hosts from weka jrpc: %w", err)
		return
	}

	vms = make([]protocol.Vm, len(interfaceGroup.Ports))
	for i, port := range interfaceGroup.Ports {
		host := hosts[port.HostId]
		vm := protocol.Vm{
			Name:         host.Hostname,
			Protocol:     protocol.NFS,
			ContainerUid: host.Uid,
		}
		vms[i] = vm
	}
	return
}
