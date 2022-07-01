package get_instances

import (
	"fmt"
	"github.com/weka/gcp-tf/cloud-functions/common"
	"strings"
)

func GetInstances(project, collectionName, documentName string) (instances []string) {
	info := common.GetClusterSizeInfo(project, collectionName, documentName)
	instancesInterfaces := info["instances"].([]interface{})
	for _, v := range instancesInterfaces {
		instances = append(instances, v.(string))
	}

	return
}

func GetInstancesBashList(project, collectionName, documentName string) string {
	return fmt.Sprintf("(\"%s\")", strings.Join(GetInstances(project, collectionName, documentName), "\" \""))
}
