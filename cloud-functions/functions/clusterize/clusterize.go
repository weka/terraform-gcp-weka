package clusterize

import (
	"context"
	"fmt"
	"strings"

	"github.com/weka/go-cloud-lib/functions_def"

	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/gcp_functions_def"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/report"
	"github.com/weka/go-cloud-lib/clusterize"
	cloudCommon "github.com/weka/go-cloud-lib/common"
	"github.com/weka/go-cloud-lib/protocol"
)

type ClusterizationParams struct {
	Project    string
	Region     string
	Zone       string
	UsernameId string
	PasswordId string
	Bucket     string
	Vm         protocol.Vm
	Cluster    clusterize.ClusterParams
	Obs        protocol.ObsParams
	// root url for cloud function calls' definitions
	CloudFuncRootUrl string
	NvmesNum         int
}

func Clusterize(ctx context.Context, p ClusterizationParams) (clusterizeScript string) {
	funcDef := gcp_functions_def.NewFuncDef(p.CloudFuncRootUrl)
	reportFunction := funcDef.GetFunctionCmdDefinition(functions_def.Report)

	state, err := common.AddInstanceToStateInstances(ctx, p.Bucket, p.Vm)
	if err != nil {
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction, p.Vm.Protocol)
		return
	}

	err = common.SetDeletionProtection(ctx, p.Project, p.Zone, p.Bucket, p.Vm.Name)
	if err != nil {
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction, p.Vm.Protocol)
		return
	}

	msg := fmt.Sprintf("This (%s) is instance %d/%d that is ready for clusterization", p.Vm.Name, len(state.Instances), state.DesiredSize)
	log.Info().Msgf(msg)
	if len(state.Instances) != p.Cluster.ClusterizationTarget {
		clusterizeScript = cloudCommon.GetScriptWithReport(msg, reportFunction, p.Vm.Protocol)
		return
	}

	if p.Cluster.SetObs {
		if p.Obs.Name == "" {
			p.Obs.Name = strings.Join([]string{p.Project, p.Cluster.Prefix, p.Cluster.ClusterName, "obs"}, "-")
			err = common.CreateBucket(ctx, p.Project, p.Region, p.Obs.Name)
			if err != nil {
				log.Error().Err(err).Send()
				err = report.Report(
					ctx,
					protocol.Report{
						Type:     "error",
						Hostname: p.Vm.Name,
						Message:  fmt.Sprintf("Failed creating obs bucket %s: %s", p.Obs.Name, err),
					},
					p.Bucket)
				if err != nil {
					log.Error().Err(err).Send()
				}
			}
		} else {
			log.Info().Msgf("Using existing obs bucket %s", p.Obs.Name)
		}
	}

	creds, err := common.GetUsernameAndPassword(ctx, p.UsernameId, p.PasswordId)
	if err != nil {
		log.Error().Err(err).Send()
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction, p.Vm.Protocol)
		return
	}
	log.Info().Msgf("Fetched weka cluster creds successfully")

	instancesNames := common.GetInstancesNames(state.Instances)
	ips := common.GetBackendsIps(ctx, p.Project, p.Zone, instancesNames)

	clusterParams := p.Cluster
	clusterParams.VMNames = instancesNames
	clusterParams.IPs = ips
	clusterParams.ObsScript = GetObsScript(p.Obs)
	clusterParams.WekaPassword = creds.Password
	clusterParams.WekaUsername = creds.Username
	clusterParams.FindDrivesScript = dedent.Dedent(common.FindDrivesScript)
	clusterParams.InstallDpdk = true
	if p.NvmesNum > 8 {
		clusterParams.PostClusterCreationScript = GetPostClusterCreationScript(p.Cluster.ClusterizationTarget)
	}

	scriptGenerator := clusterize.ClusterizeScriptGenerator{
		Params:  clusterParams,
		FuncDef: funcDef,
	}
	clusterizeScript = scriptGenerator.GetClusterizeScript()

	log.Info().Msg("Clusterization script generated")
	return
}

func GetObsScript(obsParams protocol.ObsParams) string {
	template := `
	OBS_TIERING_SSD_PERCENT=%s
	OBS_NAME="%s"

	weka fs tier s3 add gcp-bucket --hostname storage.googleapis.com --port 443 --bucket "$OBS_NAME" --protocol https --auth-method AWSSignature4
	weka fs tier s3 attach default gcp-bucket
	tiering_percent=$(echo "$full_capacity * 100 / $OBS_TIERING_SSD_PERCENT" | bc)
	weka fs update default --total-capacity "$tiering_percent"B
	`
	return fmt.Sprintf(
		dedent.Dedent(template), obsParams.TieringSsdPercent, obsParams.Name,
	)
}

func GetPostClusterCreationScript(clusterizationTarget int) string {
	template := `
	DRIVE_PROCESSES=%d //UDP and DPDK
	function wait_for_apply_completion() {
		// wait for some process to be DOWN
		while ! weka cluster process | grep -q DOWN; do
			echo "Waiting for apply to start"
			sleep 1
		done

		// while loop until all processes are UP
		count=0
		while [ $count -lt $DRIVE_PROCESSES ]; do
			echo "Waiting for apply to finish"
			sleep 1
			count=$(weka cluster process | grep drives0 | grep UP | wc -l || true)
		done
	}

	echo "Running disks override"
	weka debug override add --key override_max_disks_in_node --value 32
	weka cluster container | grep drives0 | awk '{print $1}' | xargs -IH weka cluster container dedicate H off
	weka cluster container apply -f --all
	wait_for_apply_completion
	weka cluster container | grep drives0 | awk '{print $1}' | xargs -IH weka cluster container dedicate H on
	weka cluster container apply -f --all
	wait_for_apply_completion
	`
	return fmt.Sprintf(
		dedent.Dedent(template), clusterizationTarget*2,
	)
}
