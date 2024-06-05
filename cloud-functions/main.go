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

func respondWithErr(w http.ResponseWriter, err error, status int) {
	msg := map[string]string{
		"error": err.Error(),
	}
	responseJson, _ := json.Marshal(msg)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	w.Write(responseJson)
}

func failedDecodingReqBody(w http.ResponseWriter, err error) {
	err = fmt.Errorf("failed decoding request body: %w", err)
	log.Error().Err(err).Send()
	respondWithErr(w, err, http.StatusBadRequest)
}

func ClusterizeFinalization(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	bucket := os.Getenv("BUCKET")

	ctx := r.Context()
	err := clusterize_finalization.ClusterizeFinalization(ctx, project, zone, instanceGroup, bucket)

	if err != nil {
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
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
	addFrontendNum, _ := strconv.Atoi(os.Getenv("FRONTEND_CONTAINER_CORES_NUM"))
	functionRootUrl := fmt.Sprintf("https://%s", r.Host)
	smbwEnabled, _ := strconv.ParseBool(os.Getenv("SMBW_ENABLED"))
	wekaHomeUrl := os.Getenv("WEKA_HOME_URL")
	installDpdk, _ := strconv.ParseBool(os.Getenv("INSTALL_DPDK"))
	addFrontend := false
	if addFrontendNum > 0 {
		addFrontend = true
	}

	if stripeWidth == 0 || protectionLevel == 0 || hotspare == 0 {
		err := errors.New("data protection params are not set")
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
		return
	}

	var vm protocol.Vm
	if err := json.NewDecoder(r.Body).Decode(&vm); err != nil {
		failedDecodingReqBody(w, err)
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
		Vm:         vm,
		Cluster: clusterizeCommon.ClusterParams{
			ClusterizationTarget: hostsNum,
			ClusterName:          clusterName,
			Prefix:               prefix,
			NvmesNum:             nvmesNum,
			SetObs:               setObs,
			SmbwEnabled:          smbwEnabled,
			DataProtection: clusterizeCommon.DataProtectionParams{
				StripeWidth:     stripeWidth,
				ProtectionLevel: protectionLevel,
				Hotspare:        hotspare,
			},
			AddFrontend: addFrontend,
			WekaHomeUrl: wekaHomeUrl,
			InstallDpdk: installDpdk,
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
	downBackendsRemovalTimeout, _ := time.ParseDuration(os.Getenv("DOWN_BACKENDS_REMOVAL_TIMEOUT"))

	ctx := r.Context()

	hostGroupInfoResponse, err := fetch.GetFetchDataParams(ctx, project, zone, instanceGroup, bucket, usernameId, passwordId, downBackendsRemovalTimeout)

	log.Debug().Msgf("result: %#v", hostGroupInfoResponse.WithHiddenPassword())
	if err != nil {
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
		return
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
	computeContainerNum, _ := strconv.Atoi(os.Getenv("COMPUTE_CONTAINER_CORES_NUM"))
	frontendContainerNum, _ := strconv.Atoi(os.Getenv("FRONTEND_CONTAINER_CORES_NUM"))
	driveContainerNum, _ := strconv.Atoi(os.Getenv("DRIVE_CONTAINER_CORES_NUM"))

	installUrl := os.Getenv("INSTALL_URL")
	proxyUrl := os.Getenv("PROXY_URL")
	nicsNumStr := os.Getenv("NICS_NUM")
	diskName := os.Getenv("DISK_NAME")
	installDpdk, _ := strconv.ParseBool(os.Getenv("INSTALL_DPDK"))

	functionRootUrl := fmt.Sprintf("https://%s", r.Host)

	var d struct {
		Vm string `json:"vm"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		failedDecodingReqBody(w, err)
		return
	}

	ctx := r.Context()

	params := deploy.GCPDeploymentParams{
		Project:              project,
		Zone:                 zone,
		InstanceGroup:        instanceGroup,
		UsernameId:           usernameId,
		PasswordId:           passwordId,
		TokenId:              tokenId,
		Bucket:               bucket,
		InstanceName:         d.Vm,
		NicsNumStr:           nicsNumStr,
		ComputeMemory:        computeMemory,
		InstallUrl:           installUrl,
		ProxyUrl:             proxyUrl,
		FunctionRootUrl:      functionRootUrl,
		DiskName:             diskName,
		ComputeContainerNum:  computeContainerNum,
		FrontendContainerNum: frontendContainerNum,
		DriveContainerNum:    driveContainerNum,
		InstallDpdk:          installDpdk,
		Gateways:             gateways,
	}

	bashScript, err := deploy.GetDeployScript(ctx, params)
	if err != nil {
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
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
	log.Debug().Msgf("input: %#v", info.WithHiddenPassword())

	scaleResponse, err := scale_down.ScaleDown(ctx, info)
	log.Debug().Msgf("result: %#v", scaleResponse)

	if err != nil {
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
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
	proxyUrl := os.Getenv("PROXY_URL")
	functionRootUrl := fmt.Sprintf("https://%s", r.Host)

	ctx := r.Context()
	backendsNumber := len(common.GetInstancesByClusterLabel(ctx, project, zone, clusterName))
	log.Info().Msgf("Number of backends is: %d", backendsNumber)
	state, err := common.GetClusterState(ctx, bucket)
	if err != nil {
		err = fmt.Errorf("failed getting cluster state: %w", err)
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
		return
	}
	log.Info().Msgf("Desired size is: %d", state.DesiredSize)

	currentTime := time.Now().UTC().Format("20060102150405")
	if backendsNumber < state.DesiredSize {
		for i := backendsNumber; i < state.DesiredSize; i++ {
			instanceName := fmt.Sprintf("%s-%s%03d", clusterName, currentTime, i)
			log.Info().Msgf("creating new backend instance: %s", instanceName)
			if err := scale_up.CreateInstance(ctx, project, zone, backendTemplate, instanceName, yumRepoServer, proxyUrl, functionRootUrl); err != nil {
				err = fmt.Errorf("instance %s creation failed %s.", instanceName, err)
				log.Error().Err(err).Send()
				respondWithErr(w, err, http.StatusBadRequest)
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
		failedDecodingReqBody(w, err)
		return
	}

	log.Debug().Msgf("input: %#v", scaleResponse)
	terminateResponse, err := terminate.Terminate(ctx, scaleResponse, project, zone, instanceGroup, loadBalancerName)
	log.Debug().Msgf("result: %#v", terminateResponse)
	if err != nil {
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
		return
	}
	fmt.Println("Writing terminate result")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(terminateResponse)
}

func Transient(w http.ResponseWriter, r *http.Request) {
	var terminateResponse protocol.TerminatedInstancesResponse

	if err := json.NewDecoder(r.Body).Decode(&terminateResponse); err != nil {
		failedDecodingReqBody(w, err)
		return
	}
	log.Debug().Msgf("input: %#v", terminateResponse)
	errs := terminateResponse.TransientErrors

	terminatedInstanceIds := []string{}
	for _, instance := range terminateResponse.Instances {
		terminatedInstanceIds = append(terminatedInstanceIds, instance.InstanceId)
	}
	output := fmt.Sprintf("terminated instances (%d): [%s]", len(terminatedInstanceIds), strings.Join(terminatedInstanceIds, ","))

	if len(errs) > 0 {
		output = fmt.Sprintf("the following errors were found:\n%s", strings.Join(errs, "\n"))
	}
	log.Debug().Msgf("result: %s", output)
	fmt.Println("Writing Transient result")
	fmt.Fprint(w, output)
}

func Resize(w http.ResponseWriter, r *http.Request) {
	bucket := os.Getenv("BUCKET")

	var d struct {
		Value int `json:"value"`
	}

	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		failedDecodingReqBody(w, err)
		return
	}

	ctx := r.Context()
	err := resize.UpdateValue(ctx, bucket, d.Value)
	if err != nil {
		err = fmt.Errorf("failed updating cluster size: %w", err)
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
	} else {
		fmt.Fprintf(w, "Update completed successfully")
	}
}

func JoinFinalization(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	bucket := os.Getenv("BUCKET")

	var d struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		failedDecodingReqBody(w, err)
		return
	}

	ctx := r.Context()
	err := join_finalization.JoinFinalization(ctx, project, zone, bucket, instanceGroup, d.Name)

	if err != nil {
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
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
		failedDecodingReqBody(w, err)
		return
	}

	if clusterName != d.Name {
		err := fmt.Errorf("wrong cluster name :%s", d.Name)
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
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
		failedDecodingReqBody(w, err)
		return
	}

	ctx := r.Context()
	var clusterStatus interface{}
	var err error
	if requestBody.Type == "" || requestBody.Type == "status" {
		clusterStatus, err = status.GetClusterStatus(ctx, project, zone, bucket, instanceGroup, usernameId, passwordId)
	} else if requestBody.Type == "progress" {
		clusterStatus, err = status.GetReports(ctx, project, zone, bucket, instanceGroup)
	} else {
		clusterStatus = "Invalid status type"
	}

	if err != nil {
		err = fmt.Errorf("failed retrieving status: %s", err)
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(clusterStatus)
	if err != nil {
		err = fmt.Errorf("failed decoding status: %s", err)
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
		return
	}
}

func Report(w http.ResponseWriter, r *http.Request) {
	bucket := os.Getenv("BUCKET")
	var report protocol.Report

	if err := json.NewDecoder(r.Body).Decode(&report); err != nil {
		failedDecodingReqBody(w, err)
		return
	}

	ctx := r.Context()
	err := reportPackage.Report(ctx, report, bucket)
	if err != nil {
		err = fmt.Errorf("failed reporting: %s", err)
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
		return
	}

	fmt.Fprintf(w, "The report was added successfully")
}
