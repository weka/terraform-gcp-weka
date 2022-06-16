package scale_up

import (
	"github.com/rs/zerolog/log"
	"testing"
)

func Test_join(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-instance-group"
	instanceGroupSize := getInstanceGroupSize(project, zone, instanceGroup)
	log.Info().Msgf("Instance group size is: %d", instanceGroupSize)
	desiredSize := int32(getClusterSizeInfo(project)["counter"].(int64))
	log.Info().Msgf("Desired size is: %d", desiredSize)
}
