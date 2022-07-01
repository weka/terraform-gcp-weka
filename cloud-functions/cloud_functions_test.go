package cloud_functions

import (
	"encoding/json"
	"fmt"
	"github.com/weka/gcp-tf/cloud-functions/common"
	"github.com/weka/gcp-tf/cloud-functions/functions/bunch"
	"github.com/weka/gcp-tf/cloud-functions/functions/clusterize"
	"github.com/weka/gcp-tf/cloud-functions/functions/deploy"
	"github.com/weka/gcp-tf/cloud-functions/functions/fetch"
	"github.com/weka/gcp-tf/cloud-functions/functions/get_instances"
	"github.com/weka/gcp-tf/cloud-functions/functions/increment"
	"github.com/weka/gcp-tf/cloud-functions/functions/protect"
	"github.com/weka/gcp-tf/cloud-functions/functions/scale_down"
	"github.com/weka/gcp-tf/cloud-functions/functions/scale_up"
	"github.com/weka/gcp-tf/cloud-functions/functions/terminate"
	"github.com/weka/gcp-tf/cloud-functions/functions/update_db"
	"os"
	"testing"
	"time"
)

func Test_bunch(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	clusterName := "weka-poc-instance-group"
	instanceName := "weka-poc-vm-0"
	err := bunch.AddInstanceToGroup(project, zone, clusterName, instanceName)
	if err != nil {
		t.Log("bunch test passed")
	} else {
		t.Logf("bunch test failed: %s", err)
	}
}

func Test_clusterize(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	hostsNum := "5"
	nicsNum := "4"
	gws := "(10.0.0.1 10.1.0.1 10.2.0.1 10.3.0.1)"
	clusterName := "weka-poc-instance-group"
	nvmesNumber := "2"
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"
	instanceBaseName := "weka-poc-vm"
	fmt.Printf("res:%s", clusterize.GenerateClusterizationScript(project, zone, hostsNum, nicsNum, gws, clusterName, nvmesNumber, usernameId, passwordId, instanceBaseName))
}

func Test_fetch(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-instance-group"
	clusterName := "poc"
	collectionName := "weka-poc-collection"
	documentName := "weka-poc-document"
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"
	b, err := json.Marshal(fetch.GetFetchDataParams(project, zone, instanceGroup, clusterName, collectionName, documentName, usernameId, passwordId))
	if err != nil {
		fmt.Println(err)
		return
	}

	t.Logf("res:%s", string(b))
}

func Test_get_instances(t *testing.T) {
	project := "wekaio-rnd"
	collectionName := "weka-poc-collection"
	documentName := "weka-poc-document"
	fmt.Printf("%s\n", get_instances.GetInstancesBashList(project, collectionName, documentName))
}

func Test_increment(t *testing.T) {
	project := "wekaio-rnd"
	collectionName := "weka-poc-collection"
	documentName := "weka-poc-document"
	instanceName := "weka-poc-vm-test"
	increment.Add(project, collectionName, documentName, instanceName)
	t.Log("increment test passed")
}

func Test_deploy(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	clusterName := "poc"
	usernameId := "projects/896245720241/secrets/weka-poc-username/versions/1"
	passwordId := "projects/896245720241/secrets/weka-poc-password/versions/1"
	tokenId := "projects/896245720241/secrets/weka-poc-token/versions/1"
	bashScript, err := deploy.GetJoinParams(project, zone, clusterName, usernameId, passwordId)
	if err != nil {
		t.Logf("Generating join scripts failed: %s", err)
		return
	} else {
		t.Logf("%s", bashScript)
	}

	token := os.Getenv("GET_WEKA_IO_TOKEN")
	version := "3.14.0.50-gcp-beta"

	collectionName := "weka-poc-collection"
	documentName := "weka-poc-document"
	installUrl := fmt.Sprintf("https://%s@get.weka.io/dist/v1/install/%s/%s", token, version, version)
	clusterizeUrl := "https://europe-west1-wekaio-rnd.cloudfunctions.net/weka-poc-clusterize"
	incrementUrl := "https://europe-west1-wekaio-rnd.cloudfunctions.net/weka-poc-increment"
	protectUrl := "https://europe-west1-wekaio-rnd.cloudfunctions.net/weka-poc-protect"
	bunchUrl := "https://europe-west1-wekaio-rnd.cloudfunctions.net/weka-poc-bunch"
	getInstancesUrl := "https://europe-west1-wekaio-rnd.cloudfunctions.net/weka-poc-get-instances"

	bashScript, err = deploy.GetDeployScript(project, zone, clusterName, usernameId, passwordId, tokenId, collectionName, documentName, installUrl, clusterizeUrl, incrementUrl, protectUrl, bunchUrl, getInstancesUrl)
	if err != nil {
		t.Logf("Generating deploy scripts failed: %s", err)
	} else {
		t.Logf("%s", bashScript)
	}

}

func Test_protect(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceName := "weka-poc-vm-0"
	protect.SetDeletionProtection(project, zone, instanceName)
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
	instanceGroup := "weka-instance-group"
	collectionName := "weka-poc-collection"
	documentName := "weka-poc-document"
	instanceGroupSize := scale_up.GetInstanceGroupSize(project, zone, instanceGroup)
	t.Logf("Instance group size is: %d", instanceGroupSize)
	desiredSize := int32(common.GetClusterSizeInfo(project, collectionName, documentName)["desired_size"].(int64))
	t.Logf("Desired size is: %d", desiredSize)
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

	errs := terminate.TerminateUnhealthyInstances(project, zone, instanceGroup, loadBalancerName)

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

func Test_update_db(t *testing.T) {
	project := "wekaio-rnd"
	collectionName := "weka-poc-collection"
	documentName := "weka-poc-document"
	key := "clusterized"
	value := true
	update_db.UpdateValue(project, collectionName, documentName, key, value)
}
