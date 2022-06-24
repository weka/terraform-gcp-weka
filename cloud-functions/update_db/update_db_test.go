package update_db

import (
	"testing"
)

func Test_update_db(t *testing.T) {
	project := "wekaio-rnd"
	collectionName := "weka-poc-collection"
	documentName := "weka-poc-document"
	key := "clusterized"
	value := true
	updateValue(project, collectionName, documentName, key, value)
}
