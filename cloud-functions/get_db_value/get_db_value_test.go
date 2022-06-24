package get_db_value

import (
	"fmt"
	"testing"
)

func Test_update_db(t *testing.T) {
	project := "wekaio-rnd"
	collectionName := "weka-poc-collection"
	documentName := "weka-poc-document"
	clusterInfo := getValue(project, collectionName, documentName)
	fmt.Printf("%d\n", clusterInfo["counter"].(int64))
}
