package gcp_functions_def

import (
	"fmt"

	"github.com/lithammer/dedent"
	"github.com/weka/go-cloud-lib/functions_def"
)

type GCPFuncDef struct {
	region             string
	commonFunctionName string
	supportedActions   []functions_def.FunctionName
}

func NewFuncDef(region, commonFunctionName string) functions_def.FunctionDef {
	mapping := []functions_def.FunctionName{
		functions_def.Clusterize,
		functions_def.ClusterizeFinalizaition,
		functions_def.Deploy,
		functions_def.Report,
		functions_def.Join,
		functions_def.JoinFinalization,
	}
	return &GCPFuncDef{supportedActions: mapping, commonFunctionName: commonFunctionName, region: region}
}

// each function takes json payload as an argument
// e.g. "{\"hostname\": \"$HOSTNAME\", \"type\": \"$message_type\", \"message\": \"$message\"}"
func (d *GCPFuncDef) GetFunctionCmdDefinition(name functions_def.FunctionName) string {
	var funcDef string
	if !d.isSupportedAction(name) {
		funcDefTemplate := `
		function %s {
			echo "%s function is not implemented"
		}
		`
		funcDef = fmt.Sprintf(funcDefTemplate, name, name)
	} else {
		funcDefTemplate := `
		function %s {
			local json_data=$1
			func_url=$(gcloud functions describe %s --region %s --format='get(serviceConfig.uri)')
			curl $func_url?action=%s -H "Authorization:bearer $(gcloud auth print-identity-token)" -H "Content-Type:application/json" -d "$json_data"
		}
		`
		funcDef = fmt.Sprintf(funcDefTemplate, name, d.commonFunctionName, d.region, name)
	}
	return dedent.Dedent(funcDef)
}

func (d *GCPFuncDef) isSupportedAction(name functions_def.FunctionName) bool {
	for _, action := range d.supportedActions {
		if action == name {
			return true
		}
	}
	return false
}
