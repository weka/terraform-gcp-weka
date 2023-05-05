package clusterize

import (
	"context"
	"fmt"

	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/gcp_functions_def"
	"github.com/weka/go-cloud-lib/clusterize"
)

type ClusterizationParams struct {
	Project    string
	Zone       string
	UsernameId string
	PasswordId string
	Bucket     string
	VmName     string
	Cluster    clusterize.ClusterParams
}

func GetErrorScript(err error) string {
	s := `
	#!/bin/bash
	<<'###ERROR'
	%s
	###ERROR
	exit 1
	`
	return fmt.Sprintf(dedent.Dedent(s), err.Error())
}

func Clusterize(ctx context.Context, p ClusterizationParams) (clusterizeScript string) {
	instancesNames, err := common.AddInstanceToStateInstances(ctx, p.Bucket, p.VmName)
	if err != nil {
		clusterizeScript = GetErrorScript(err)
		return
	}

	err = common.SetDeletionProtection(ctx, p.Project, p.Zone, p.VmName)
	if err != nil {
		clusterizeScript = GetErrorScript(err)
		return
	}

	initialSize := p.Cluster.HostsNum
	if len(instancesNames) != initialSize {
		msg := fmt.Sprintf("This is instance number %d that is ready for clusterization (not last one), doing nothing.", len(instancesNames))
		log.Info().Msgf(msg)

		clusterizeScript = dedent.Dedent(fmt.Sprintf(`
		#!/bin/bash
		echo "%s"
		`, msg))
		return
	}

	creds, err := common.GetUsernameAndPassword(ctx, p.UsernameId, p.PasswordId)
	if err != nil {
		log.Error().Msgf("%s", err)
		clusterizeScript = GetErrorScript(err)
		return
	}
	log.Info().Msgf("Fetched weka cluster creds successfully")

	funcDef := gcp_functions_def.NewFuncDef()

	ips := common.GetBackendsIps(ctx, p.Project, p.Zone, instancesNames)

	clusterParams := p.Cluster
	clusterParams.VMNames = instancesNames
	clusterParams.IPs = ips
	clusterParams.DebugOverrideCmds = "echo 'nothing here'"
	clusterParams.ObsScript = "echo 'nothing here'"
	clusterParams.WekaPassword = creds.Password
	clusterParams.WekaUsername = creds.Username
	clusterParams.InstallDpdk = true

	scriptGenerator := clusterize.ClusterizeScriptGenerator{
		Params:  clusterParams,
		FuncDef: funcDef,
	}
	clusterizeScript = scriptGenerator.GetClusterizeScript()

	log.Info().Msg("Clusterization script generated")
	return
}
