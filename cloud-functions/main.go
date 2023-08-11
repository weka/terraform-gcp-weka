package cloud_functions

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/storage"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/clusterize"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/clusterize_finalization"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/deploy"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/fetch"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/join_finalization"
	reportPackage "github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/report"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/resize"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/scale_up"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/status"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/terminate"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/terminate_cluster"
	clusterizeCommon "github.com/weka/go-cloud-lib/clusterize"
	"github.com/weka/go-cloud-lib/protocol"
	"github.com/weka/go-cloud-lib/scale_down"
)

func ClusterizeFinalization(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	bucket := os.Getenv("BUCKET")

	ctx := r.Context()
	err := clusterize_finalization.ClusterizeFinalization(ctx, project, zone, instanceGroup, bucket)

	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, "ClusterizeFinalization completed successfully")
	}
}

func CloudInternal(w http.ResponseWriter, r *http.Request) {
	queryParams := r.URL.Query()
	action := queryParams.Get("action")

	switch action {
	case "clusterize":
		Clusterize(w, r)
	case "clusterize_finalization":
		ClusterizeFinalization(w, r)
	case "deploy":
		Deploy(w, r)
	case "fetch":
		Fetch(w, r)
	case "join_finalization":
		JoinFinalization(w, r)
	case "report":
		Report(w, r)
	case "resize":
		Resize(w, r)
	case "terminate":
		Terminate(w, r)
	case "terminate_cluster":
		TerminateCluster(w, r)
	case "transient":
		Transient(w, r)
	case "scale_up":
		ScaleUp(w, r)
	default:
		fmt.Fprintf(w, "Unknown action: %s", action)
	}
}

func Clusterize(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	region := os.Getenv("REGION")
	hostsNum, _ := strconv.Atoi(os.Getenv("HOSTS_NUM"))
	clusterName := os.Getenv("CLUSTER_NAME")
	prefix := os.Getenv("PREFIX")
	nvmesNum, _ := strconv.Atoi(os.Getenv("NVMES_NUM"))
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")
	bucket := os.Getenv("BUCKET")
	// data protection-related vars
	stripeWidth, _ := strconv.Atoi(os.Getenv("STRIPE_WIDTH"))
	protectionLevel, _ := strconv.Atoi(os.Getenv("PROTECTION_LEVEL"))
	hotspare, _ := strconv.Atoi(os.Getenv("HOTSPARE"))
	setObs, _ := strconv.ParseBool(os.Getenv("SET_OBS"))
	obsName := os.Getenv("OBS_NAME")
	tieringSsdPercent := os.Getenv("OBS_TIERING_SSD_PERCENT")
	addFrontendNum, _ := strconv.Atoi(os.Getenv("NUM_FRONTEND_CONTAINERS"))
	functionRootUrl := fmt.Sprintf("https://%s", r.Host)
	addFrontend := false
	if addFrontendNum > 0 {
		addFrontend = true
	}

	if stripeWidth == 0 || protectionLevel == 0 || hotspare == 0 {
		fmt.Fprint(w, "Failed getting data protection params")
		return
	}

	var d struct {
		Vm string `json:"vm"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	ctx := r.Context()

	params := clusterize.ClusterizationParams{
		Project:    project,
		Region:     region,
		Zone:       zone,
		UsernameId: usernameId,
		PasswordId: passwordId,
		Bucket:     bucket,
		VmName:     d.Vm,
		Cluster: clusterizeCommon.ClusterParams{
			HostsNum:    hostsNum,
			ClusterName: clusterName,
			Prefix:      prefix,
			NvmesNum:    nvmesNum,
			SetObs:      setObs,
			DataProtection: clusterizeCommon.DataProtectionParams{
				StripeWidth:     stripeWidth,
				ProtectionLevel: protectionLevel,
				Hotspare:        hotspare,
			},
			AddFrontend: addFrontend,
		},
		Obs: protocol.ObsParams{
			Name:              obsName,
			TieringSsdPercent: tieringSsdPercent,
		},
		CloudFuncRootUrl: functionRootUrl,
	}
	fmt.Fprint(w, clusterize.Clusterize(ctx, params))
}

func Fetch(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	bucket := os.Getenv("BUCKET")
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")

	ctx := r.Context()

	hostGroupInfoResponse, err := fetch.GetFetchDataParams(ctx, project, zone, instanceGroup, bucket, usernameId, passwordId)
	log.Debug().Msgf("result: %#v", hostGroupInfoResponse)
	if err != nil {
		panic(fmt.Sprintf("An error occurred: %s", err))
	}
	fmt.Println("Writing fetch result")
	w.Header().Set("Content-Type", "application/json")
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
	gateways := strings.Split(os.Getenv("GATEWAYS"), ",")

	computeMemory := os.Getenv("COMPUTE_MEMORY")
	computeContainerNum, _ := strconv.Atoi(os.Getenv("NUM_COMPUTE_CONTAINERS"))
	frontendContainerNum, _ := strconv.Atoi(os.Getenv("NUM_FRONTEND_CONTAINERS"))
	driveContainerNum, _ := strconv.Atoi(os.Getenv("NUM_DRIVE_CONTAINERS"))

	installUrl := os.Getenv("INSTALL_URL")
	nics_num_str := os.Getenv("NICS_NUM")

	functionRootUrl := fmt.Sprintf("https://%s", r.Host)

	var d struct {
		Vm string `json:"vm"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	ctx := r.Context()

	bashScript, err := deploy.GetDeployScript(
		ctx,
		project,
		zone,
		instanceGroup,
		usernameId,
		passwordId,
		tokenId,
		bucket,
		d.Vm,
		nics_num_str,
		computeMemory,
		installUrl,
		functionRootUrl,
		computeContainerNum,
		frontendContainerNum,
		driveContainerNum,
		gateways,
	)
	if err != nil {
		_, _ = fmt.Fprintf(w, "%s", err)
		return
	}
	w.Write([]byte(bashScript))
}

func ScaleDown(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var info protocol.HostGroupInfoResponse
	if err := json.NewDecoder(r.Body).Decode(&info); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}
	log.Debug().Msgf("input: %#v", info)

	scaleResponse, err := scale_down.ScaleDown(ctx, info)
	log.Debug().Msgf("result: %#v", scaleResponse)

	if err != nil {
		_, _ = fmt.Fprintf(w, "%s", err)
		return
	}
	fmt.Println("Writing scale result")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(scaleResponse)
}

func ScaleUp(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	clusterName := os.Getenv("CLUSTER_NAME")
	backendTemplate := os.Getenv("BACKEND_TEMPLATE")
	bucket := os.Getenv("BUCKET")
	yumRepoServer := os.Getenv("YUM_REPO_SERVER")
	functionRootUrl := fmt.Sprintf("https://%s", r.Host)

	ctx := r.Context()
	backendsNumber := len(common.GetInstancesByClusterLabel(ctx, project, zone, clusterName))
	log.Info().Msgf("Number of backends is: %d", backendsNumber)
	state, err := common.GetClusterState(ctx, bucket)
	if err != nil {
		return
	}
	log.Info().Msgf("Desired size is: %d", state.DesiredSize)

	currentTime := time.Now().UTC().Format("20060102150405")
	if backendsNumber < state.DesiredSize {
		for i := backendsNumber; i < state.DesiredSize; i++ {
			instanceName := fmt.Sprintf("%s-%s%03d", clusterName, currentTime, i)
			log.Info().Msgf("creating new backend instance: %s", instanceName)
			if err := scale_up.CreateInstance(ctx, project, zone, backendTemplate, instanceName, yumRepoServer, functionRootUrl); err != nil {
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

	ctx := r.Context()
	if err := json.NewDecoder(r.Body).Decode(&scaleResponse); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}

	log.Debug().Msgf("input: %#v", scaleResponse)
	terminateResponse, err := terminate.Terminate(ctx, scaleResponse, project, zone, instanceGroup, loadBalancerName)
	log.Debug().Msgf("result: %#v", terminateResponse)
	if err != nil {
		panic(fmt.Sprintf("An error occurred: %s", err))
	}
	fmt.Println("Writing terminate result")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(terminateResponse)

}

func Transient(w http.ResponseWriter, r *http.Request) {
	var terminateResponse protocol.TerminatedInstancesResponse

	if err := json.NewDecoder(r.Body).Decode(&terminateResponse); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}
	log.Debug().Msgf("input: %#v", terminateResponse)
	errs := terminateResponse.TransientErrors
	output := ""
	if len(errs) > 0 {
		output = fmt.Sprintf("the following errors were found:\n%s", strings.Join(errs, "\n"))
	}
	log.Debug().Msgf("result: %s", output)
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

	ctx := r.Context()
	err := resize.UpdateValue(ctx, bucket, d.Value)
	if err != nil {
		fmt.Fprintf(w, "Update failed: %s", err)
	} else {
		fmt.Fprintf(w, "Update completed successfully")
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

	ctx := r.Context()
	err := join_finalization.JoinFinalization(ctx, project, zone, instanceGroup, d.Name)

	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, "JoinFinalization completed successfully")
	}
}

func TerminateCluster(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	bucket := os.Getenv("BUCKET")
	clusterName := os.Getenv("CLUSTER_NAME")

	// to lower the risk of unintended cluster termination, we will not have the cluster name as an env var but require
	//to pass it as param on the termination request

	var d struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	if clusterName != d.Name {
		fmt.Fprintf(w, fmt.Sprintf("Wrong cluster name :%s", d.Name))
		return
	}

	ctx := r.Context()
	err := terminate_cluster.DeleteStateObject(ctx, bucket)
	if err != nil {
		if errors.Is(err, storage.ErrObjectNotExist) {
			fmt.Fprintf(w, "No cluster state object to delete.")
		} else {
			fmt.Fprintf(w, fmt.Sprintf("Failed deleting state object:%s.", err))
			return
		}
	} else {
		fmt.Fprintf(w, "Deleted cluster state successfully.")
	}

	terminatingInstances, errs := terminate_cluster.TerminateInstances(ctx, project, zone, d.Name)
	if len(errs) > 0 {
		fmt.Fprintf(w, fmt.Sprintf("Got the following failure while terminating instances:%s.", errs))
	}

	if len(terminatingInstances) > 0 {
		fmt.Fprintf(w, fmt.Sprintf("Terminated %d instances:%s", len(terminatingInstances), terminatingInstances))
	} else {
		fmt.Fprintf(w, "No instances to terminate")
	}
}

func Status(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	bucket := os.Getenv("BUCKET")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")

	var requestBody struct {
		Type string `json:"type"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	ctx := r.Context()
	var clusterStatus interface{}
	var err error
	if requestBody.Type == "" || requestBody.Type == "status" {
		clusterStatus, err = status.GetClusterStatus(ctx, project, zone, bucket, instanceGroup, usernameId, passwordId)
	} else if requestBody.Type == "progress" {
		clusterStatus, err = status.GetReports(ctx, bucket)
	} else {
		clusterStatus = "Invalid status type"
	}

	if err != nil {
		fmt.Fprintf(w, "Failed retrieving status: %s", err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(clusterStatus)
	if err != nil {
		fmt.Fprintf(w, "Failed decoding status: %s", err)
	}
}

func Report(w http.ResponseWriter, r *http.Request) {
	bucket := os.Getenv("BUCKET")
	var report protocol.Report

	if err := json.NewDecoder(r.Body).Decode(&report); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	ctx := r.Context()
	err := reportPackage.Report(ctx, report, bucket)
	if err != nil {
		fmt.Fprintf(w, "Failed reporting: %s", err)
		return
	}

	fmt.Fprintf(w, "The report was added successfully")
}
