package clusterize

import (
	"context"
	"fmt"
	"github.com/weka/go-cloud-lib/functions_def"
	"strings"

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
	VmName     string
	Cluster    clusterize.ClusterParams
	Obs        protocol.ObsParams
	// root url for cloud function calls' definitions
	CloudFuncRootUrl string
}

func Clusterize(ctx context.Context, p ClusterizationParams) (clusterizeScript string) {
	funcDef := gcp_functions_def.NewFuncDef(p.CloudFuncRootUrl)
	reportFunction := funcDef.GetFunctionCmdDefinition(functions_def.Report)

	instancesNames, err := common.AddInstanceToStateInstances(ctx, p.Bucket, p.VmName)
	if err != nil {
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction)
		return
	}

	err = common.SetDeletionProtection(ctx, p.Project, p.Zone, p.VmName)
	if err != nil {
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction)
		return
	}

	initialSize := p.Cluster.HostsNum
	msg := fmt.Sprintf("This (%s) is instance %d/%d that is ready for clusterization", p.VmName, len(instancesNames), initialSize)
	log.Info().Msgf(msg)
	if len(instancesNames) != initialSize {
		clusterizeScript = dedent.Dedent(fmt.Sprintf(`
		#!/bin/bash
		echo "%s"
		`, msg))
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
						Hostname: p.VmName,
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
		log.Error().Msgf("%s", err)
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction)
		return
	}
	log.Info().Msgf("Fetched weka cluster creds successfully")

	ips := common.GetBackendsIps(ctx, p.Project, p.Zone, instancesNames)

	clusterParams := p.Cluster
	clusterParams.VMNames = instancesNames
	clusterParams.IPs = ips
	clusterParams.DebugOverrideCmds = "echo 'nothing here'"
	clusterParams.ObsScript = GetObsScript(p.Obs)
	clusterParams.WekaPassword = creds.Password
	clusterParams.WekaUsername = creds.Username
	clusterParams.FindDrivesScript = dedent.Dedent(common.FindDrivesScript)
	clusterParams.InstallDpdk = true

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
