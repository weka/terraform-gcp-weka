package transient

import (
	"encoding/json"
	"fmt"
	"github.com/weka/gcp-tf/cloud-functions/transient/protocol"
	"net/http"
	"strings"
)

func Transient(w http.ResponseWriter, r *http.Request) {

	var terminateResponse protocol.TerminatedInstancesResponse

	if err := json.NewDecoder(r.Body).Decode(&terminateResponse); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}

	errs := terminateResponse.TransientErrors
	output := ""
	if len(errs) > 0 {
		output = fmt.Sprintf("the following errors were found:\n%s", strings.Join(errs, "\n"))
	}

	fmt.Println("Writing Transient result")

	fmt.Fprintf(w, output)
}
