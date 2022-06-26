package fetch

import (
	"encoding/json"
	"fmt"
	"log"
	"testing"
)

func Test_fetch(t *testing.T) {
	project := "wekaio-rnd"
	zone := "europe-west1-b"
	instanceGroup := "weka-instance-group"
	clusterName := "poc"
	collectionName := "weka-poc-collection"
	documentName := "weka-poc-document"
	b, err := json.Marshal(GetFetchDataParams(project, zone, instanceGroup, clusterName, collectionName, documentName))
	if err != nil {
		fmt.Println(err)
		return
	}

	log.Printf("res:%s", string(b))
}
