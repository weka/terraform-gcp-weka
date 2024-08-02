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

type Protocol struct {
	Protocol protocol.ProtocolGW `json:"protocol"`
}

func ClusterizeFinalization(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	bucket := os.Getenv("BUCKET")

	var vmProtocol Protocol
	if err := json.NewDecoder(r.Body).Decode(&vmProtocol); err != nil {
		failedDecodingReqBody(w, err)
		return
	}

	var stateObject string
	var instanceGroup string
	if vmProtocol.Protocol == protocol.NFS {
		stateObject = os.Getenv("NFS_STATE_OBJ_NAME")
		instanceGroup = os.Getenv("NFS_INSTANCE_GROUP")
	} else {
		stateObject = os.Getenv("STATE_OBJ_NAME")
		instanceGroup = os.Getenv("INSTANCE_GROUP")
	}

	ctx := r.Context()
	err := clusterize_finalization.ClusterizeFinalization(ctx, project, zone, instanceGroup, bucket, stateObject, vmProtocol.Protocol)

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
	case "join_nfs_finalization":
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
	deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")
	adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
	bucket := os.Getenv("BUCKET")
	stateObject := os.Getenv("STATE_OBJ_NAME")
	nfsStateObject := os.Getenv("NFS_STATE_OBJ_NAME")
	// data protection-related vars
	stripeWidth, _ := strconv.Atoi(os.Getenv("STRIPE_WIDTH"))
	protectionLevel, _ := strconv.Atoi(os.Getenv("PROTECTION_LEVEL"))
	hotspare, _ := strconv.Atoi(os.Getenv("HOTSPARE"))
	setObs, _ := strconv.ParseBool(os.Getenv("SET_OBS"))
	obsName := os.Getenv("OBS_NAME")
	tieringSsdPercent := os.Getenv("OBS_TIERING_SSD_PERCENT")
	tieringTargetSsdRetention, _ := strconv.Atoi(os.Getenv("TIERING_TARGET_SSD_RETENTION"))
	tieringStartDemote, _ := strconv.Atoi(os.Getenv("TIERING_START_DEMOTE"))
	addFrontendNum, _ := strconv.Atoi(os.Getenv("FRONTEND_CONTAINER_CORES_NUM"))
	functionRootUrl := fmt.Sprintf("https://%s", r.Host)
	createConfigFs, _ := strconv.ParseBool(os.Getenv("CREATE_CONFIG_FS"))
	wekaHomeUrl := os.Getenv("WEKA_HOME_URL")
	installDpdk, _ := strconv.ParseBool(os.Getenv("INSTALL_DPDK"))
	backendLbIp := os.Getenv("BACKEND_LB_IP")
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
		Project:              project,
		Region:               region,
		Zone:                 zone,
		UsernameId:           usernameId,
		AdminPasswordId:      adminPasswordId,
		DeploymentPasswordId: deploymentPasswordId,
		Bucket:               bucket,
		StateObject:          stateObject,
		Vm:                   vm,
		Cluster: clusterizeCommon.ClusterParams{
			ClusterizationTarget: hostsNum,
			ClusterName:          clusterName,
			Prefix:               prefix,
			SetObs:               setObs,
			CreateConfigFs:       createConfigFs,
			DataProtection: clusterizeCommon.DataProtectionParams{
				StripeWidth:     stripeWidth,
				ProtectionLevel: protectionLevel,
				Hotspare:        hotspare,
			},
			AddFrontend:               addFrontend,
			WekaHomeUrl:               wekaHomeUrl,
			InstallDpdk:               installDpdk,
			TieringTargetSSDRetention: tieringTargetSsdRetention,
			TieringStartDemote:        tieringStartDemote,
		},
		Obs: protocol.ObsParams{
			Name:              obsName,
			TieringSsdPercent: tieringSsdPercent,
		},
		CloudFuncRootUrl: functionRootUrl,
		NvmesNum:         nvmesNum,
		NFSStateObject:   nfsStateObject,
		BackendLbIp:      backendLbIp,
	}

	var clusterizeScript string
	if vm.Protocol == protocol.NFS {
		clusterizeScript = clusterize.NFSClusterize(ctx, params)
	} else if vm.Protocol == protocol.SMB || vm.Protocol == protocol.SMBW || vm.Protocol == protocol.S3 {
		clusterizeScript = "echo 'SMB / S3 clusterization is not supported'"
	} else {
		clusterizeScript = clusterize.Clusterize(ctx, params)
	}
	fmt.Fprint(w, clusterizeScript)
}

func Fetch(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	bucket := os.Getenv("BUCKET")
	downBackendsRemovalTimeout, _ := time.ParseDuration(os.Getenv("DOWN_BACKENDS_REMOVAL_TIMEOUT"))
	stateObject := os.Getenv("STATE_OBJ_NAME")
	nfsStateObject := "" // Disabling Scale down. To return support, need to change to: 'os.Getenv("NFS_STATE_OBJ_NAME")'
	nfsInstanceGroup := os.Getenv("NFS_INSTANCE_GROUP")
	usernameId := os.Getenv("USER_NAME_ID")
	deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")
	adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")

	var input protocol.FetchRequest
	if r.Body != nil && r.Body != http.NoBody {
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			failedDecodingReqBody(w, err)
			return
		}
	}

	ctx := r.Context()

	p := fetch.FetchInput{
		Project:                    project,
		Zone:                       zone,
		InstanceGroup:              instanceGroup,
		Bucket:                     bucket,
		StateObject:                stateObject,
		DeploymentUsernameId:       usernameId,
		DeploymentPasswordId:       deploymentPasswordId,
		AdminPasswordId:            adminPasswordId,
		NFSStateObject:             nfsStateObject,
		NFSInstanceGroup:           nfsInstanceGroup,
		DownBackendsRemovalTimeout: downBackendsRemovalTimeout,
		ShowAdminPassword:          input.ShowAdminPassword,
	}

	hostGroupInfoResponse, err := fetch.FetchHostGroupInfo(ctx, p)

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
	tokenId := os.Getenv("TOKEN_ID")
	bucket := os.Getenv("BUCKET")
	stateObject := os.Getenv("STATE_OBJ_NAME")
	nfsStateObject := os.Getenv("NFS_STATE_OBJ_NAME")
	nfsInstanceGroup := os.Getenv("NFS_INSTANCE_GROUP")
	gateways := strings.Split(os.Getenv("GATEWAYS"), ",")
	backendLbIp := os.Getenv("BACKEND_LB_IP")

	computeMemory := os.Getenv("COMPUTE_MEMORY")
	computeContainerNum, _ := strconv.Atoi(os.Getenv("COMPUTE_CONTAINER_CORES_NUM"))
	frontendContainerNum, _ := strconv.Atoi(os.Getenv("FRONTEND_CONTAINER_CORES_NUM"))
	driveContainerNum, _ := strconv.Atoi(os.Getenv("DRIVE_CONTAINER_CORES_NUM"))

	installUrl := os.Getenv("INSTALL_URL")
	proxyUrl := os.Getenv("PROXY_URL")
	nicsNumStr := os.Getenv("NICS_NUM")
	nvmesNum, _ := strconv.Atoi(os.Getenv("NVMES_NUM"))
	diskName := os.Getenv("DISK_NAME")
	installDpdk, _ := strconv.ParseBool(os.Getenv("INSTALL_DPDK"))

	functionRootUrl := fmt.Sprintf("https://%s", r.Host)
	// nfs params
	nfsInterfaceGroupName := os.Getenv("NFS_INTERFACE_GROUP_NAME")
	nfsProtocolgwsNum, _ := strconv.Atoi(os.Getenv("NFS_PROTOCOL_GATEWAYS_NUM"))
	nfsSecondaryIpsNum, _ := strconv.Atoi(os.Getenv("NFS_SECONDARY_IPS_NUM"))
	nfsProtocolGatewayFeCoresNum, _ := strconv.Atoi(os.Getenv("NFS_PROTOCOL_GATEWAY_FE_CORES_NUM"))
	smbProtocolGatewayFeCoresNum, _ := strconv.Atoi(os.Getenv("SMB_PROTOCOL_GATEWAY_FE_CORES_NUM"))
	s3ProtocolGatewayFeCoresNum, _ := strconv.Atoi(os.Getenv("S3_PROTOCOL_GATEWAY_FE_CORES_NUM"))
	nfsDiskSize, _ := strconv.Atoi(os.Getenv("NFS_DISK_SIZE"))
	smbDiskSize, _ := strconv.Atoi(os.Getenv("SMB_DISK_SIZE"))
	s3DiskSize, _ := strconv.Atoi(os.Getenv("S3_DISK_SIZE"))
	tracesPerFrontend, _ := strconv.Atoi(os.Getenv("TRACES_PER_FRONTEND"))

	var vm protocol.Vm
	if err := json.NewDecoder(r.Body).Decode(&vm); err != nil {
		failedDecodingReqBody(w, err)
		return
	}

	ctx := r.Context()

	params := deploy.GCPDeploymentParams{
		Project:               project,
		Zone:                  zone,
		InstanceGroup:         instanceGroup,
		TokenId:               tokenId,
		Bucket:                bucket,
		StateObject:           stateObject,
		InstanceName:          vm.Name,
		NicsNumStr:            nicsNumStr,
		NvmesNum:              nvmesNum,
		ComputeMemory:         computeMemory,
		InstallUrl:            installUrl,
		ProxyUrl:              proxyUrl,
		FunctionRootUrl:       functionRootUrl,
		DiskName:              diskName,
		ComputeContainerNum:   computeContainerNum,
		FrontendContainerNum:  frontendContainerNum,
		DriveContainerNum:     driveContainerNum,
		InstallDpdk:           installDpdk,
		Gateways:              gateways,
		BackendLbIp:           backendLbIp,
		NFSInstanceGroup:      nfsInstanceGroup,
		NFSStateObject:        nfsStateObject,
		NFSInterfaceGroupName: nfsInterfaceGroupName,
		NFSProtocolGWsNum:     nfsProtocolgwsNum,
		NFSGatewayFeCoresNum:  nfsProtocolGatewayFeCoresNum,
		NFSSecondaryIpsNum:    nfsSecondaryIpsNum,
		NFSDiskSize:           nfsDiskSize + tracesPerFrontend*nfsProtocolGatewayFeCoresNum,
		SMBGatewayFeCoresNum:  smbProtocolGatewayFeCoresNum,
		SMBDiskSize:           smbDiskSize + tracesPerFrontend*smbProtocolGatewayFeCoresNum,
		S3GatewayFeCoresNum:   s3ProtocolGatewayFeCoresNum,
		S3DiskSize:            s3DiskSize + tracesPerFrontend*s3ProtocolGatewayFeCoresNum,
	}

	var bashScript string
	var err error
	if vm.Protocol == protocol.NFS {
		bashScript, err = deploy.GetNfsDeployScript(ctx, params)
	} else if vm.Protocol == protocol.SMB || vm.Protocol == protocol.SMBW || vm.Protocol == protocol.S3 {
		bashScript, err = deploy.GetProtocolDeployScript(ctx, params, vm.Protocol)
	} else if vm.Protocol != "" {
		err = fmt.Errorf("unsupported protocol: %s", vm.Protocol)
	} else {
		bashScript, err = deploy.GetBackendsDeployScript(ctx, params)
	}

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
	stateObject := os.Getenv("STATE_OBJ_NAME")
	nfsStateObject := os.Getenv("NFS_STATE_OBJ_NAME")
	nfsGatewaysName := os.Getenv("NFS_GATEWAYS_NAME")
	nfsTemplateName := os.Getenv("NFS_GATEWAYS_TEMPLATE_NAME")
	nfsInterfaceGroupName := os.Getenv("NFS_INTERFACE_GROUP_NAME")
	nfsInstanceGroup := os.Getenv("NFS_INSTANCE_GROUP")
	yumRepoServer := os.Getenv("YUM_REPO_SERVER")
	proxyUrl := os.Getenv("PROXY_URL")
	functionRootUrl := fmt.Sprintf("https://%s", r.Host)
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	usernameId := os.Getenv("USER_NAME_ID")
	adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
	deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")
	nfsSecondaryIpsNum, _ := strconv.Atoi(os.Getenv("NFS_SECONDARY_IPS_NUM"))

	ctx := r.Context()
	backends, err := common.GetInstancesByClusterLabel(ctx, project, zone, clusterName)
	if err != nil {
		err = fmt.Errorf("failed getting instances by cluster label: %w", err)
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
	}
	backendsNumber := len(backends)
	log.Info().Msgf("Number of backends is: %d", backendsNumber)

	state, err := common.GetClusterState(ctx, bucket, stateObject)
	if err != nil {
		err = fmt.Errorf("failed getting cluster state: %w", err)
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
		return
	}
	log.Info().Msgf("Desired size is: %d", state.DesiredSize)

	var createdInstances []string

	currentTime := time.Now().UTC().Format("20060102150405")
	if backendsNumber < state.DesiredSize {
		for i := backendsNumber; i < state.DesiredSize; i++ {
			instanceName := fmt.Sprintf("%s-%s%03d", clusterName, currentTime, i)
			log.Info().Msgf("creating new backend instance: %s", instanceName)
			if err := scale_up.CreateBackendInstance(ctx, project, zone, backendTemplate, instanceName, yumRepoServer, proxyUrl, functionRootUrl); err != nil {
				err = fmt.Errorf("instance %s creation failed %s.", instanceName, err)
				log.Error().Err(err).Send()
				respondWithErr(w, err, http.StatusBadRequest)
				return
			} else {
				createdInstances = append(createdInstances, instanceName)
				log.Info().Msgf("Instance %s creation completed successfully", instanceName)
			}
		}
	}

	var nfsGatewaysNumber int
	var nfsDesiredSize int
	var nfsInstancesMigrated bool

	if nfsStateObject != "" {
		nfsGateways, err := common.GetInstancesByProtocolGwLabel(ctx, project, zone, nfsGatewaysName)
		if err != nil {
			err = fmt.Errorf("failed getting instances by nfs protocol gw label: %w", err)
			log.Error().Err(err).Send()
			respondWithErr(w, err, http.StatusBadRequest)
			return
		}
		nfsGatewaysNumber = len(nfsGateways)
		log.Info().Msgf("Number of NFS gateways is: %d", nfsGatewaysNumber)

		nfsState, err := common.GetClusterState(ctx, bucket, nfsStateObject)
		if err != nil {
			err = fmt.Errorf("failed getting nfs cluster state: %w", err)
			log.Error().Err(err).Send()
			respondWithErr(w, err, http.StatusBadRequest)
			return
		}
		log.Info().Msgf("NFS desired size is: %d", nfsState.DesiredSize)
		nfsDesiredSize = nfsState.DesiredSize
		nfsInstancesMigrated = nfsState.NfsInstancesMigrated
	}

	if nfsStateObject != "" && !nfsInstancesMigrated && state.Clusterized {
		migratedInstances, err := scale_up.MigrateExistingNFSInstances(
			ctx, project, zone, bucket, nfsStateObject, nfsGatewaysName, nfsInterfaceGroupName, nfsInstanceGroup, instanceGroup, usernameId, deploymentPasswordId, adminPasswordId,
		)
		if err != nil {
			err = fmt.Errorf("failed migrating existing NFS instances: %w", err)
			log.Error().Err(err).Send()
			respondWithErr(w, err, http.StatusBadRequest)
			return
		} else {
			// setting deletion protection outside of the migration function, because it modifies state object
			for _, vmName := range migratedInstances {
				common.SetDeletionProtection(ctx, project, zone, bucket, nfsStateObject, vmName)
			}
			fmt.Fprintf(w, "Migrating existing NFS instances completed successfully: %v. ", migratedInstances)
		}
	} else if nfsGatewaysNumber < nfsDesiredSize {
		for i := nfsGatewaysNumber; i < nfsDesiredSize; i++ {
			instanceName := fmt.Sprintf("%s-%s%03d", nfsGatewaysName, currentTime, i)
			log.Info().Msgf("creating new NFS instance: %s", instanceName)
			if err := scale_up.CreateNFSInstance(ctx, project, zone, nfsTemplateName, instanceName, yumRepoServer, proxyUrl, functionRootUrl, nfsSecondaryIpsNum); err != nil {
				err = fmt.Errorf("instance %s creation failed %s.", instanceName, err)
				log.Error().Err(err).Send()
				respondWithErr(w, err, http.StatusBadRequest)
				return
			} else {
				createdInstances = append(createdInstances, instanceName)
				log.Info().Msgf("Instance %s creation completed successfully", instanceName)
			}
		}
	}

	if len(createdInstances) > 0 {
		fmt.Fprintf(w, "Instances creation has started: %v", createdInstances)
	} else {
		log.Info().Msg("Nothing to do")
		fmt.Fprintf(w, "Nothing to do")
	}
}

func Terminate(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	nfsInstanceGroup := "" // Disabling Scale down. To return support, need to change to: os.Getenv("NFS_INSTANCE_GROUP")
	loadBalancerName := os.Getenv("LOAD_BALANCER_NAME")

	var scaleResponse protocol.ScaleResponse

	ctx := r.Context()
	if err := json.NewDecoder(r.Body).Decode(&scaleResponse); err != nil {
		failedDecodingReqBody(w, err)
		return
	}

	log.Debug().Msgf("input: %#v", scaleResponse)
	terminateResponse, err := terminate.Terminate(ctx, scaleResponse, project, zone, instanceGroup, loadBalancerName)
	log.Debug().Msgf("backends terminate result: %#v", terminateResponse)
	if err != nil {
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
		return
	}

	// terminate NFS instances (if NFS is configured)
	if nfsInstanceGroup != "" {
		nfsTerminateResponse, err := terminate.Terminate(ctx, scaleResponse, project, zone, nfsInstanceGroup, loadBalancerName)
		log.Debug().Msgf("nfs terminate result: %#v", nfsTerminateResponse)
		if err != nil {
			log.Error().Err(err).Send()
			respondWithErr(w, err, http.StatusBadRequest)
			return
		}
		// merge responses
		terminateResponse.Instances = append(terminateResponse.Instances, nfsTerminateResponse.Instances...)
		terminateResponse.TransientErrors = append(terminateResponse.TransientErrors, nfsTerminateResponse.TransientErrors...)
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
		Value    int     `json:"value"`
		Protocol *string `json:"protocol"`
	}

	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		failedDecodingReqBody(w, err)
		return
	}

	var stateObject string
	if d.Protocol != nil && *d.Protocol == "nfs" {
		stateObject = os.Getenv("NFS_STATE_OBJ_NAME")
	} else {
		stateObject = os.Getenv("STATE_OBJ_NAME")
	}

	ctx := r.Context()
	err := resize.UpdateValue(ctx, bucket, stateObject, d.Value)
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
	bucket := os.Getenv("BUCKET")

	var d struct {
		Name     string              `json:"name"`
		Protocol protocol.ProtocolGW `json:"protocol"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		failedDecodingReqBody(w, err)
		return
	}

	var stateObject string
	var instanceGroup string
	if d.Protocol == protocol.NFS {
		stateObject = os.Getenv("NFS_STATE_OBJ_NAME")
		instanceGroup = os.Getenv("NFS_INSTANCE_GROUP")
	} else {
		stateObject = os.Getenv("STATE_OBJ_NAME")
		instanceGroup = os.Getenv("INSTANCE_GROUP")
	}

	ctx := r.Context()
	err := join_finalization.JoinFinalization(ctx, project, zone, bucket, stateObject, instanceGroup, d.Name, d.Protocol)

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
	stateObject := os.Getenv("STATE_OBJ_NAME")
	nfsStateObject := os.Getenv("NFS_STATE_OBJ_NAME")
	nfsGatewaysName := os.Getenv("NFS_GATEWAYS_NAME")

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

	var terminatingInstances []string

	// delete NFS instances if NFS is configured
	if nfsGatewaysName != "" {
		err := terminate_cluster.DeleteStateObject(ctx, bucket, nfsStateObject)
		if err != nil {
			if errors.Is(err, storage.ErrObjectNotExist) {
				fmt.Fprint(w, "No NFS state object to delete.")
			} else {
				fmt.Fprintf(w, "Failed deleting NFS state object: %s.", err)
				return
			}
		} else {
			fmt.Fprint(w, "Deleted NFS state successfully.")
		}

		terminatingNfsInstances, errs := terminate_cluster.TerminateInstances(ctx, project, zone, common.WekaProtocolGwLabelKey, nfsGatewaysName, true)
		if len(errs) > 0 {
			fmt.Fprintf(w, "Got the following failure while terminating NFS instances: %s.", errs)
		}

		if len(terminatingNfsInstances) > 0 {
			fmt.Fprintf(w, "Terminated %d NFS instances: %s", len(terminatingNfsInstances), terminatingNfsInstances)
		} else {
			fmt.Fprint(w, "No NFS instances to terminate.")
		}
	}

	err := terminate_cluster.DeleteStateObject(ctx, bucket, stateObject)
	if err != nil {
		if errors.Is(err, storage.ErrObjectNotExist) {
			fmt.Fprint(w, "No cluster state object to delete.")
		} else {
			fmt.Fprintf(w, "Failed deleting state object: %s.", err)
			return
		}
	} else {
		fmt.Fprint(w, "Deleted cluster state successfully.")
	}

	terminatingInstances, errs := terminate_cluster.TerminateInstances(ctx, project, zone, common.WekaClusterLabelKey, d.Name, false)
	if len(errs) > 0 {
		fmt.Fprintf(w, "Got the following failure while terminating instances: %s.", errs)
	}

	if len(terminatingInstances) > 0 {
		fmt.Fprintf(w, "Terminated %d instances: %s", len(terminatingInstances), terminatingInstances)
	} else {
		fmt.Fprint(w, "No instances to terminate")
	}
}

func Status(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	bucket := os.Getenv("BUCKET")
	stateObject := os.Getenv("STATE_OBJ_NAME")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	usernameId := os.Getenv("USER_NAME_ID")
	adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
	deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")
	nfsStateObject := os.Getenv("NFS_STATE_OBJ_NAME")
	nfsInstanceGroup := os.Getenv("NFS_INSTANCE_GROUP")

	var requestBody struct {
		Type     string `json:"type"`
		Protocol string `json:"protocol"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		failedDecodingReqBody(w, err)
		return
	}

	ctx := r.Context()
	var clusterStatus interface{}
	var err error
	if requestBody.Type == "" || requestBody.Type == "status" {
		clusterStatus, err = status.GetClusterStatus(ctx, project, zone, bucket, stateObject, instanceGroup, usernameId, deploymentPasswordId, adminPasswordId)
	} else if requestBody.Type == "progress" && requestBody.Protocol == "" {
		clusterStatus, err = status.GetReports(ctx, project, zone, bucket, stateObject, instanceGroup)
	} else if requestBody.Type == "progress" && requestBody.Protocol == "nfs" {
		clusterStatus, err = status.GetReports(ctx, project, zone, bucket, nfsStateObject, nfsInstanceGroup)
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

	var stateObject string
	if report.Protocol == protocol.NFS {
		stateObject = os.Getenv("NFS_STATE_OBJ_NAME")
	} else {
		stateObject = os.Getenv("STATE_OBJ_NAME")
	}

	ctx := r.Context()
	err := reportPackage.Report(ctx, report, bucket, stateObject)
	if err != nil {
		err = fmt.Errorf("failed reporting: %s", err)
		log.Error().Err(err).Send()
		respondWithErr(w, err, http.StatusBadRequest)
		return
	}

	fmt.Fprintf(w, "The report was added successfully")
}
