package bunch

import (
	"fmt"
	"testing"
)

func Test_bunch(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	clusterName := "weka-poc-instance-group"
	instanceName := "weka-poc-vm-0"
	fmt.Printf("Added %s to instance group", addInstanceToGroup(project, zone, clusterName, instanceName))
}
