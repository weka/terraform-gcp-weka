package terminate

import (
	"fmt"
	"testing"
	"time"
)

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

	errs := terminateUnhealthyInstances(project, zone, instanceGroup, loadBalancerName)

	if len(errs) > 0 {
		t.Logf("error calling terminateUnhealthyInstances %s", errs)
	} else {
		t.Log("terminateUnhealthyInstances succeeded")
	}

	fmt.Println("ToDo: write test")
}
