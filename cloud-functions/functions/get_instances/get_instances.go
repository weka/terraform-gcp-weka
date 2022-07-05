package get_instances

import (
	"fmt"
	"github.com/weka/gcp-tf/cloud-functions/common"
	"strings"
)

func GetInstances(bucket string) (instances []string) {
	state, err := common.GetClusterState(bucket)
	if err != nil {
		return
	}
	instances = state.Instances
	return
}

func GetInstancesBashList(bucket string) string {
	return fmt.Sprintf("(\"%s\")", strings.Join(GetInstances(bucket), "\" \""))
}
