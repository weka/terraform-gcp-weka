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

func Clusterize(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	hostsNum, _ := strconv.Atoi(os.Getenv("HOSTS_NUM"))
	clusterName := os.Getenv("CLUSTER_NAME")
	nvmesNum, _ := strconv.Atoi(os.Getenv("NVMES_NUM"))
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")
	bucket := os.Getenv("BUCKET")
	// data protection-related vars
	stripeWidth, _ := strconv.Atoi(os.Getenv("STRIPE_WIDTH"))
	protectionLevel, _ := strconv.Atoi(os.Getenv("PROTECTION_LEVEL"))
	hotspare, _ := strconv.Atoi(os.Getenv("HOTSPARE"))

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
		Zone:       zone,
		UsernameId: usernameId,
		PasswordId: passwordId,
		Bucket:     bucket,
		VmName:     d.Vm,
		Cluster: clusterizeCommon.ClusterParams{
			HostsNum:    hostsNum,
			ClusterName: clusterName,
			NvmesNum:    nvmesNum,
			SetObs:      false,
			DataProtection: clusterizeCommon.DataProtectionParams{
				StripeWidth:     stripeWidth,
				ProtectionLevel: protectionLevel,
				Hotspare:        hotspare,
			},
		},
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
	computeContainerNum := os.Getenv("NUM_COMPUTE_CONTAINERS")
	frontendContainerNum := os.Getenv("NUM_FRONTEND_CONTAINERS")
	driveContainerNum := os.Getenv("NUM_DRIVE_CONTAINERS")

	installUrl := os.Getenv("INSTALL_URL")
	nics_num_str := os.Getenv("NICS_NUM")

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
		computeMemory,
		computeContainerNum,
		frontendContainerNum,
		driveContainerNum,
		nics_num_str,
		installUrl,
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
			if err := scale_up.CreateInstance(ctx, project, zone, backendTemplate, instanceName); err != nil {
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

	ctx := r.Context()
	clusterStatus, err := status.GetClusterStatus(ctx, project, zone, bucket, instanceGroup, usernameId, passwordId)
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
