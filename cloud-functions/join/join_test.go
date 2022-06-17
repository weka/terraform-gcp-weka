package join

import (
	"encoding/json"
	"fmt"
	"log"
	"testing"
)

func Test_join(t *testing.T) {
	bashScript, err := GetJoinParams("wekaio-rnd", "europe-west1-b", "poc")
	if err != nil {
		panic(err)
	}
	b, err := json.Marshal(bashScript)
	if err != nil {
		fmt.Println(err)
		return
	}

	log.Printf("res:%s", string(b))
}
