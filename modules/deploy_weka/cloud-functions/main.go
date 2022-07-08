package cloud_functions

import (
	"encoding/json"
	"fmt"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/cloud-functions/common"
	"github.com/weka/gcp-tf/cloud-functions/functions/bunch"
	"github.com/weka/gcp-tf/cloud-functions/functions/clusterize"
	"github.com/weka/gcp-tf/cloud-functions/functions/deploy"
	"github.com/weka/gcp-tf/cloud-functions/functions/fetch"
	"github.com/weka/gcp-tf/cloud-functions/functions/get_instances"
	"github.com/weka/gcp-tf/cloud-functions/functions/increment"
	"github.com/weka/gcp-tf/cloud-functions/functions/protect"
	"github.com/weka/gcp-tf/cloud-functions/functions/resize"
	"github.com/weka/gcp-tf/cloud-functions/functions/scale_down"
	"github.com/weka/gcp-tf/cloud-functions/functions/scale_up"
	"github.com/weka/gcp-tf/cloud-functions/functions/terminate"
	"github.com/weka/gcp-tf/cloud-functions/protocol"
	"net/http"
	"os"
	"strings"
)

func Bunch(w http.ResponseWriter, r *http.Request) {
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
	err := bunch.AddInstanceToGroup(project, zone, instanceGroup, d.Name)

	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, "Added %s to instance group %s successfully", d.Name, instanceGroup)
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
	instanceBaseName := os.Getenv("INSTANCE_BASE_NAME")

	fmt.Fprintf(w, clusterize.GenerateClusterizationScript(project, zone, hostsNum, nicsNum, gws, clusterName, nvmesMumber, usernameId, passwordId, instanceBaseName))
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
	json.NewEncoder(w).Encode(fetch.GetFetchDataParams(project, zone, instanceGroup, bucket, usernameId, passwordId))
}

func GetInstances(w http.ResponseWriter, r *http.Request) {
	bucket := os.Getenv("BUCKET")

	fmt.Fprintf(w, "%s", get_instances.GetInstancesBashList(bucket))
}

func Increment(w http.ResponseWriter, r *http.Request) {
	bucket := os.Getenv("BUCKET")

	var d struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	err := increment.Add(bucket, d.Name)
	if err != nil {
		fmt.Fprintf(w, "Increment failed: %s", err)
	} else {
		fmt.Fprintf(w, "Increment completed successfully")
	}
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
	incrementUrl := os.Getenv("INCREMENT_URL")
	protectUrl := os.Getenv("PROTECT_URL")
	bunchUrl := os.Getenv("BUNCH_URL")
	getInstancesUrl := os.Getenv("GET_INSTANCES_URL")

	bashScript, err := deploy.GetDeployScript(project, zone, instanceGroup, usernameId, passwordId, tokenId, bucket, installUrl, clusterizeUrl, incrementUrl, protectUrl, bunchUrl, getInstancesUrl)
	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, bashScript)
	}
}

func Protect(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")

	var d struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	err := protect.SetDeletionProtection(project, zone, d.Name)
	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, "Termination protection was set successfully on %s", d.Name)
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
	json.NewEncoder(w).Encode(scale_down.ScaleDown(info))

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
			log.Info().Msg("creating new backend instance")
			if err := scale_up.CreateInstance(project, zone, backendTemplate, instanceName); err != nil {
				fmt.Fprintf(w, "Instance %s creation failed %s.", instanceName, err)
			} else {
				fmt.Fprintf(w, "Instance %s creation has started.", instanceName)
			}
		}
	} else {
		fmt.Fprintf(w, "Nothing to do!")
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

	terminate.Terminate(w, scaleResponse, project, zone, instanceGroup, loadBalancerName)
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
