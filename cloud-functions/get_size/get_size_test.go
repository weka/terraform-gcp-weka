package get_size

import (
	"fmt"
	"testing"
)

func Test_update_db(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-poc-instance-group"
	fmt.Printf("%d\n", getInstanceGroupSize(project, zone, instanceGroup))
}
