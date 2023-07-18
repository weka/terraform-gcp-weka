package gcp_functions_def

import (
	"fmt"

	"github.com/lithammer/dedent"
	"github.com/weka/go-cloud-lib/functions_def"
)

type GCPFuncDef struct {
	rootUrl          string
	supportedActions map[functions_def.FunctionName]bool
}

func NewFuncDef(rootUrl string) functions_def.FunctionDef {
	mapping := map[functions_def.FunctionName]bool{
		functions_def.Clusterize:              true,
		functions_def.ClusterizeFinalizaition: true,
		functions_def.Deploy:                  true,
		functions_def.Report:                  true,
		functions_def.Join:                    true,
		functions_def.JoinFinalization:        true,
	}
	return &GCPFuncDef{supportedActions: mapping, rootUrl: rootUrl}
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
			curl %s?action=%s -H "Authorization:bearer $(gcloud auth print-identity-token)" -H "Content-Type:application/json" -d "$json_data"
		}
		`
		funcDef = fmt.Sprintf(funcDefTemplate, name, d.rootUrl, name)
	}
	return dedent.Dedent(funcDef)
}

func (d *GCPFuncDef) isSupportedAction(name functions_def.FunctionName) bool {
	val, ok := d.supportedActions[name]
	return ok && val
}
