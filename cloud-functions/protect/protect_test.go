package protect

import (
	"testing"
)

func Test_update_db(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceName := "weka-poc-vm-0"
	setDeletionProtection(project, zone, instanceName)
}
