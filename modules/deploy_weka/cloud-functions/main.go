package cloud_functions

import (
	"encoding/json"
	"fmt"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/clusterize"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/clusterize_finalization"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/deploy"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/fetch"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/join_finalization"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/resize"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/scale_down"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/scale_up"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/terminate"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/protocol"
	"net/http"
	"os"
	"strings"
)

func ClusterizeFinalization(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")

	bucket := os.Getenv("BUCKET")

	err := clusterize_finalization.ClusterizeFinalization(project, zone, instanceGroup, bucket)

	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, "ClusterizeFinalization completed successfully")
	}
}

func Clusterize(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	hostsNum := os.Getenv("HOSTS_NUM")
	nicsNum := os.Getenv("NICS_NUM")
	gws := os.Getenv("GWS")
	clusterName := os.Getenv("CLUSTER_NAME")
	nvmesMumber := os.Getenv("NVMES_NUM")
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")
	bucket := os.Getenv("BUCKET")
	clusterizeFinalizationUrl := os.Getenv("CLUSTERIZE_FINALIZATION_URL")

	var d struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	fmt.Fprintf(w, clusterize.Clusterize(project, zone, hostsNum, nicsNum, gws, clusterName, nvmesMumber, usernameId, passwordId, bucket, d.Name, clusterizeFinalizationUrl))
}

func Fetch(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	bucket := os.Getenv("BUCKET")
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")

	fmt.Println("Writing fetch result")
	w.Header().Set("Content-Type", "application/json")
	hostGroupInfoResponse, err := fetch.GetFetchDataParams(project, zone, instanceGroup, bucket, usernameId, passwordId)
	if err != nil {
		panic(fmt.Sprintf("An error occurred: %s", err))
	}
	json.NewEncoder(w).Encode(hostGroupInfoResponse)
}

func Deploy(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")
	tokenId := os.Getenv("TOKEN_ID")

	bucket := os.Getenv("BUCKET")

	installUrl := os.Getenv("INSTALL_URL")
	clusterizeUrl := os.Getenv("CLUSTERIZE_URL")
	joinFinalizationUrl := os.Getenv("JOIN_FINALIZATION_URL")

	bashScript, err := deploy.GetDeployScript(project, zone, instanceGroup, usernameId, passwordId, tokenId, bucket, installUrl, clusterizeUrl, joinFinalizationUrl)
	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, bashScript)
	}
}

func ScaleDown(w http.ResponseWriter, r *http.Request) {
	var info protocol.HostGroupInfoResponse
	if err := json.NewDecoder(r.Body).Decode(&info); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}

	fmt.Println("Writing scale result")
	w.Header().Set("Content-Type", "application/json")

	scaleResponse, err := scale_down.ScaleDown(info)
	if err != nil {
		panic(fmt.Sprintf("An error occurred: %s", err))
	}
	json.NewEncoder(w).Encode(scaleResponse)
}

func ScaleUp(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	clusterName := os.Getenv("CLUSTER_NAME")
	backendTemplate := os.Getenv("BACKEND_TEMPLATE")
	bucket := os.Getenv("BUCKET")
	instanceBaseName := os.Getenv("INSTANCE_BASE_NAME")

	backendsNumber := len(common.GetInstancesByClusterLabel(project, zone, clusterName))
	log.Info().Msgf("Number of backends is: %d", backendsNumber)
	state, err := common.GetClusterState(bucket)
	if err != nil {
		return
	}
	log.Info().Msgf("Desired size is: %d", state.DesiredSize)

	if backendsNumber < state.DesiredSize {
		for i := backendsNumber; i < state.DesiredSize; i++ {
			instanceName := fmt.Sprintf("%s-%s", instanceBaseName, uuid.New().String())
			log.Info().Msgf("creating new backend instance: %s", instanceName)
			if err := scale_up.CreateInstance(project, zone, backendTemplate, instanceName); err != nil {
				fmt.Fprintf(w, "Instance %s creation failed %s.", instanceName, err)
			} else {
				log.Info().Msgf("Instance %s creation completed successfully", instanceName)
				fmt.Fprintf(w, "Instance %s creation has started.", instanceName)
			}
		}
	} else {
		log.Info().Msg("Nothing to do")
		fmt.Fprintf(w, "Nothing to do")
	}
}

func Terminate(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	loadBalancerName := os.Getenv("LOAD_BALANCER_NAME")

	var scaleResponse protocol.ScaleResponse

	if err := json.NewDecoder(r.Body).Decode(&scaleResponse); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}

	err := terminate.Terminate(w, scaleResponse, project, zone, instanceGroup, loadBalancerName)
	if err != nil {
		panic(fmt.Sprintf("An error occurred: %s", err))
	}
}

func Transient(w http.ResponseWriter, r *http.Request) {

	var terminateResponse protocol.TerminatedInstancesResponse

	if err := json.NewDecoder(r.Body).Decode(&terminateResponse); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}

	errs := terminateResponse.TransientErrors
	output := ""
	if len(errs) > 0 {
		output = fmt.Sprintf("the following errors were found:\n%s", strings.Join(errs, "\n"))
	}

	fmt.Println("Writing Transient result")

	fmt.Fprintf(w, output)
}

func Resize(w http.ResponseWriter, r *http.Request) {
	bucket := os.Getenv("BUCKET")

	var d struct {
		Value int `json:"value"`
	}

	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}

	err := resize.UpdateValue(bucket, d.Value)
	if err != nil {
		fmt.Fprintf(w, "Updade failed: %s", err)
	} else {
		fmt.Fprintf(w, "Updade completed successfully")
	}
}

func JoinFinalization(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")

	var d struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	err := join_finalization.JoinFinalization(project, zone, instanceGroup, d.Name)

	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, "JoinFinalization completed successfully")
	}
}
