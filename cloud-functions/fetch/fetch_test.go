package fetch

import (
	"encoding/json"
	"fmt"
	"log"
	"testing"
)

func Test_fetch(t *testing.T) {
	b, err := json.Marshal(GetFetchDataParams("wekaio-rnd", "europe-west1-b", "weka-igm", "poc"))
	if err != nil {
		fmt.Println(err)
		return
	}

	log.Printf("res:%s", string(b))
}
