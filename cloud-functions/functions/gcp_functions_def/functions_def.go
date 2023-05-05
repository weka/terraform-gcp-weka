package gcp_functions_def

import (
	"fmt"
	"os"

	"github.com/lithammer/dedent"
	"github.com/weka/go-cloud-lib/functions_def"
)

type GCPFuncDef struct {
	functionUrlMapping map[functions_def.FunctionName]string
}

func NewFuncDef() functions_def.FunctionDef {
	mapping := map[functions_def.FunctionName]string{
		functions_def.Clusterize:              os.Getenv("CLUSTERIZE_URL"),
		functions_def.ClusterizeFinalizaition: os.Getenv("CLUSTERIZE_FINALIZATION_URL"),
		functions_def.Deploy:                  os.Getenv("DEPLOY_URL"),
		functions_def.Report:                  os.Getenv("REPORT_URL"),
		functions_def.Join:                    os.Getenv("JOIN_URL"),
		functions_def.JoinFinalization:        os.Getenv("JOIN_FINALIZATION_URL"),
	}
	return &GCPFuncDef{functionUrlMapping: mapping}
}

// each function takes json payload as an argument
// e.g. "{\"hostname\": \"$HOSTNAME\", \"type\": \"$message_type\", \"message\": \"$message\"}"
func (d *GCPFuncDef) GetFunctionCmdDefinition(name functions_def.FunctionName) string {
	functionUrl, ok := d.functionUrlMapping[name]
	var funcDef string
	if !ok {
		funcDefTemplate := `
		function %s {
			echo "%s function is not supported"
		}
		`
		funcDef = fmt.Sprintf(funcDefTemplate, name, name)
	} else if functionUrl == "" {
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
			curl %s -H "Authorization:bearer $(gcloud auth print-identity-token)" -H "Content-Type:application/json" -d "$json_data"
		}
		`
		funcDef = fmt.Sprintf(funcDefTemplate, name, functionUrl)
	}
	return dedent.Dedent(funcDef)
}
