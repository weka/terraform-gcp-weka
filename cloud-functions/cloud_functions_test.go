package cloud_functions

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/clusterize"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/clusterize_finalization"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/deploy"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/fetch"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/resize"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/scale_up"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/status"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/terminate"
	clusterizeCommon "github.com/weka/go-cloud-lib/clusterize"
	"github.com/weka/go-cloud-lib/protocol"
	"github.com/weka/go-cloud-lib/scale_down"
)

func Test_bunch(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-instance-group"
	bucket := "weka-poc-state"

	ctx := context.TODO()
	err := clusterize_finalization.ClusterizeFinalization(ctx, project, zone, instanceGroup, bucket)
	if err != nil {
		t.Log("bunch test passed")
	} else {
		t.Logf("bunch test failed: %s", err)
	}
}

func Test_clusterize(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	hostsNum := 5
	clusterName := "poc"
	nvmesNumber := 2
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"

	bucket := "weka-poc-wekaio-rnd-state"
	instanceName := "weka-poc-vm-test"

	vm := protocol.Vm{
		Name: instanceName,
	}

	dataProtectionParams := clusterizeCommon.DataProtectionParams{
		StripeWidth:     2,
		ProtectionLevel: 2,
		Hotspare:        1,
	}

	params := clusterize.ClusterizationParams{
		Project:    project,
		Zone:       zone,
		UsernameId: usernameId,
		PasswordId: passwordId,
		Bucket:     bucket,
		Vm:         vm,
		Cluster: clusterizeCommon.ClusterParams{
			ClusterizationTarget: hostsNum,
			ClusterName:          clusterName,
			NvmesNum:             nvmesNumber,
			SetObs:               false,
			DataProtection:       dataProtectionParams,
		},
	}

	ctx := context.TODO()
	fmt.Printf("res:%s", clusterize.Clusterize(ctx, params))
}

func Test_fetch(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-instance-group"
	bucket := "weka-poc-state"
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"

	ctx := context.TODO()
	result, err := fetch.GetFetchDataParams(ctx, project, zone, instanceGroup, bucket, usernameId, passwordId)
	if err != nil {
		fmt.Println(err)
		return
	}
	b, err := json.Marshal(result)
	if err != nil {
		fmt.Println(err)
		return
	}

	t.Logf("res:%s", string(b))
}

func Test_deploy(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-instance-group"
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"
	tokenId := "projects/896245720241/secrets/weka-poc-token/versions/1"
	nicNum := "3"
	gws := []string{"10.0.0.1", "10.1.0.1", "10.2.0.1", "10.3.0.1"}
	computeMemory := "8GB"
	computeContainerNum := 1
	frontendContainerNum := 1
	driveContainerNum := 1
	instanceName := "abc"
	functionRootUrl := "https://europe-west1-wekaio-rnd.cloudfunctions.net"

	token := os.Getenv("GET_WEKA_IO_TOKEN")
	version := "4.0.1.37-gcp"
	installUrl := fmt.Sprintf("https://%s@get.weka.io/dist/v1/install/%s/%s", token, version, version)

	bucket := "weka-poc-state"
	diskName := "weka-poc-disk"

	ctx := context.TODO()

	params := deploy.GCPDeploymentParams{
		Project:              project,
		Zone:                 zone,
		InstanceGroup:        instanceGroup,
		UsernameId:           usernameId,
		PasswordId:           passwordId,
		TokenId:              tokenId,
		Bucket:               bucket,
		InstanceName:         instanceName,
		NicsNumStr:           nicNum,
		ComputeMemory:        computeMemory,
		InstallUrl:           installUrl,
		ProxyUrl:             "",
		FunctionRootUrl:      functionRootUrl,
		DiskName:             diskName,
		ComputeContainerNum:  computeContainerNum,
		FrontendContainerNum: frontendContainerNum,
		DriveContainerNum:    driveContainerNum,
		Gateways:             gws,
	}

	bashScript, err := deploy.GetDeployScript(ctx, params)
	if err != nil {
		t.Logf("Generating deploy scripts failed: %s", err)
	} else {
		t.Logf("%s", bashScript)
	}

}

func Test_calculateDeactivateTarget(t *testing.T) {
	type args struct {
		nHealthy      int
		nUnhealthy    int
		nDeactivating int
		desired       int
	}
	tests := []struct {
		name string
		args args
		want int
	}{
		{"manualDeactivate", args{9, 0, 1, 10}, 1},
		{"downscale", args{20, 0, 0, 10}, 10},
		{"downscaleP2", args{10, 0, 6, 10}, 6},
		{"downfailures", args{8, 2, 6, 10}, 6},
		{"failures", args{20, 10, 0, 30}, 2},
		{"failuresP2", args{20, 8, 2, 30}, 2},
		{"upscale", args{20, 0, 0, 30}, 0},
		{"upscaleFailures", args{20, 3, 0, 30}, 2},
		{"totalfailure", args{0, 20, 0, 30}, 2},
		{"totalfailureP2", args{0, 18, 2, 30}, 2},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := scale_down.CalculateDeactivateTarget(tt.args.nHealthy, tt.args.nUnhealthy, tt.args.nDeactivating, tt.args.desired); got != tt.want {
				t.Errorf("CalculateDeactivateTarget() = %v, want %v", got, tt.want)
			}
		})
	}
}

func Test_scaleUp(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	clusterName := "poc"
	instanceName := "weka-poc-vm-test"
	backendTemplate := "projects/wekaio-rnd/global/instanceTemplates/weka-poc-backends"
	functionRootUrl := "https://europe-west1-wekaio-rnd.cloudfunctions.net"
	yumRepoServer := ""
	proxyUrl := ""
	ctx := context.TODO()
	scale_up.CreateInstance(ctx, project, zone, backendTemplate, instanceName, yumRepoServer, proxyUrl, functionRootUrl)
	instances := common.GetInstancesByClusterLabel(ctx, project, zone, clusterName)
	instanceGroupSize := len(instances)
	t.Logf("Instance group size is: %d", instanceGroupSize)
	for _, instance := range instances {
		t.Logf("%s:%s", *instance.Name, *instance.Status)
	}
}

func Test_Terminate(t *testing.T) {
	_, err := time.Parse(time.RFC3339, "2022-06-21T21:59:55.156-07:00")

	if err != nil {
		t.Logf("error formatting creation time %s", err.Error())
	} else {
		t.Log("Formatting succeeded")
	}

	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-poc-instance-group"
	loadBalancerName := "weka-poc-lb-backend"

	ctx := context.TODO()
	errs := terminate.TerminateUnhealthyInstances(ctx, project, zone, instanceGroup, loadBalancerName)

	if len(errs) > 0 {
		t.Logf("error calling TerminateUnhealthyInstances %s", errs)
	} else {
		t.Log("TerminateUnhealthyInstances succeeded")
	}

	fmt.Println("ToDo: write test")
}

func Test_Transient(t *testing.T) {
	fmt.Println("ToDo: write test")
}

func Test_resize(t *testing.T) {
	bucket := "weka-poc-state"
	newDesiredValue := 6
	ctx := context.TODO()
	resize.UpdateValue(ctx, bucket, newDesiredValue)
}

func Test_status(t *testing.T) {
	// This will pass only before clusterization, after clusterization it will fail trying to fetch weka status
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	bucket := "weka-poc-wekaio-rnd"
	instanceGroup := "weka-poc-instance-group"
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"

	ctx := context.TODO()
	clusterStatus, err := status.GetClusterStatus(ctx, project, zone, bucket, instanceGroup, usernameId, passwordId)
	if err != nil {
		t.Logf("Failed getting status %s", err)
	} else {
		clusterStatusJson, err := json.Marshal(clusterStatus)
		if err != nil {
			t.Logf("Failed decoding status %s", err)
		}
		fmt.Println(string(clusterStatusJson))
	}
}
