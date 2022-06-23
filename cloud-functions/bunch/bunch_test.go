package bunch

import (
	"fmt"
	"testing"
)

func Test_bunch(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	clusterName := "poc"
	instanceGroup := "weka-instance-group"
	fmt.Printf("Added %s to instance group", addInstancesToGroup(project, zone, clusterName, instanceGroup))
}
