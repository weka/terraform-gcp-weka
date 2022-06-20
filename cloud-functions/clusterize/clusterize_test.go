package clusterize

import (
	"fmt"
	"testing"
)

func Test_clusterize(t *testing.T) {
	fmt.Printf("res:%s", generateClusterizationScript("wekaio-rnd", "europe-west1-b", "5", "4", "(10.0.0.1 10.1.0.1 10.2.0.1 10.3.0.1)", "poc", "2"))
}
