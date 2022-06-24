package increment

import (
	"testing"
)

func Test_update_db(t *testing.T) {
	project := "wekaio-rnd"
	collectionName := "weka-poc-collection"
	documentName := "weka-poc-document"
	increment(project, collectionName, documentName)
}
