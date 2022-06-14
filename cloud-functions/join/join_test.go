package join

import (
	"encoding/json"
	"fmt"
	"log"
	"testing"
)

func Test_join(t *testing.T) {
	b, err := json.Marshal(GetJoinParams("wekaio-rnd", "europe-west1-b", "poc"))
	if err != nil {
		fmt.Println(err)
		return
	}

	log.Printf("res:%s", string(b))
}
