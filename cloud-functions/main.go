package cloud_functions

import (
	"encoding/json"
	"fmt"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/cloud-functions/bunch"
	"github.com/weka/gcp-tf/cloud-functions/clusterize"
	"github.com/weka/gcp-tf/cloud-functions/fetch"
	"github.com/weka/gcp-tf/cloud-functions/get_db_value"
	"github.com/weka/gcp-tf/cloud-functions/get_size"
	"github.com/weka/gcp-tf/cloud-functions/increment"
	"github.com/weka/gcp-tf/cloud-functions/join"
	"github.com/weka/gcp-tf/cloud-functions/protect"
	"github.com/weka/gcp-tf/cloud-functions/protocol"
	"github.com/weka/gcp-tf/cloud-functions/scale_down"
	"github.com/weka/gcp-tf/cloud-functions/scale_up"
	"github.com/weka/gcp-tf/cloud-functions/terminate"
	"github.com/weka/gcp-tf/cloud-functions/update_db"
	"net/http"
	"os"
	"strconv"
	"strings"
)

func Bunch(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")

	var d struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}
	err := bunch.AddInstanceToGroup(project, zone, instanceGroup, d.Name)

	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, "Added %s to instance group %s successfully", d.Name, instanceGroup)
	}
}

func Clusterize(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	hostsNum := os.Getenv("HOSTS_NUM")
	nicsNum := os.Getenv("NICS_NUM")
	gws := os.Getenv("GWS")
	clusterName := os.Getenv("CLUSTER_NAME")
	nvmesMumber := os.Getenv("NVMES_NUM")
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")
	instanceBaseName := os.Getenv("INSTANCE_BASE_NAME")
	getSizeUrl := os.Getenv("GET_SIZE_URL")

	fmt.Fprintf(w, clusterize.GenerateClusterizationScript(project, zone, hostsNum, nicsNum, gws, clusterName, nvmesMumber, usernameId, passwordId, instanceBaseName, getSizeUrl))
}

func Fetch(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	clusterName := os.Getenv("CLUSTER_NAME")
	collectionName := os.Getenv("COLLECTION_NAME")
	documentName := os.Getenv("DOCUMENT_NAME")
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")

	fmt.Println("Writing fetch result")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(fetch.GetFetchDataParams(project, zone, instanceGroup, clusterName, collectionName, documentName, usernameId, passwordId))
}

func GetDbValue(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	collectionName := os.Getenv("COLLECTION_NAME")
	documentName := os.Getenv("DOCUMENT_NAME")

	clusterInfo := get_db_value.GetValue(project, collectionName, documentName)
	counter := clusterInfo["counter"].(int64)

	fmt.Fprintf(w, "%d", counter)
}

func GetSize(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")

	fmt.Fprintf(w, "%d", get_size.GetInstanceGroupSize(project, zone, instanceGroup))
}

func Increment(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	collectionName := os.Getenv("COLLECTION_NAME")
	documentName := os.Getenv("DOCUMENT_NAME")

	err := increment.IncrementCounter(project, collectionName, documentName)
	if err != nil {
		fmt.Fprintf(w, "Increment failed: %s", err)
	} else {
		fmt.Fprintf(w, "Increment completed successfully")
	}
}

func Join(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	clusterName := os.Getenv("CLUSTER_NAME")
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")

	fmt.Println("Getting join params")
	bashScript, err := join.GetJoinParams(project, zone, clusterName, usernameId, passwordId)
	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, bashScript)
	}
}

func Protect(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")

	var d struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	err := protect.SetDeletionProtection(project, zone, d.Name)
	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, "Termination protection was set successfully on %s", d.Name)
	}
}

func ScaleDown(w http.ResponseWriter, r *http.Request) {
	var info protocol.HostGroupInfoResponse
	if err := json.NewDecoder(r.Body).Decode(&info); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}

	fmt.Println("Writing scale result")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(scale_down.ScaleDown(info))

}

func ScaleUp(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	backendTemplate := os.Getenv("BACKEND_TEMPLATE")
	clusterizeTemplate := os.Getenv("CLUSTERIZE_TEMPLATE")
	joinTemplate := os.Getenv("JOIN_TEMPLATE")
	collectionName := os.Getenv("COLLECTION_NAME")
	documentName := os.Getenv("DOCUMENT_NAME")
	instanceBaseName := os.Getenv("INSTANCE_BASE_NAME")

	instanceGroupSize := scale_up.GetInstanceGroupSize(project, zone, instanceGroup)
	log.Info().Msgf("Instance group size is: %d", instanceGroupSize)
	clusterInfo := scale_up.GetClusterSizeInfo(project, collectionName, documentName)
	initialSize := int32(clusterInfo["initial_size"].(int64))
	desiredSize := int32(clusterInfo["desired_size"].(int64))
	counter := int32(clusterInfo["counter"].(int64))
	log.Info().Msgf("Desired size is: %d", desiredSize)

	if counter >= initialSize {
		if desiredSize > counter {
			if instanceGroupSize < initialSize {
				fmt.Fprintf(w, "Can't join new instance, clusterization isn't done")
				return
			}

			for i := counter; i < desiredSize; i++ {
				instanceName := fmt.Sprintf("%s-%s", instanceBaseName, uuid.New().String())
				log.Info().Msg("weka is clusterized joining new instance")
				if err := scale_up.CreateInstance(project, zone, joinTemplate, instanceGroup, instanceName); err != nil {
					fmt.Fprintf(w, "Instance %s creation failed %s.", instanceName, err)
				} else {
					fmt.Fprintf(w, "Instance %s join has started.", instanceName)
				}
			}
			return
		}
	} else {
		i := counter
		for ; i < initialSize-1; i++ {
			instanceName := fmt.Sprintf("%s-%d", instanceBaseName, i)
			log.Info().Msg("weka is not clusterized, creating new instance")
			if err := scale_up.CreateInstance(project, zone, backendTemplate, instanceGroup, instanceName); err != nil {
				fmt.Fprintf(w, "Instance %s creation failed %s.", instanceName, err)
			} else {
				fmt.Fprintf(w, "Backend instance %s was created successfully.", instanceName)

			}
		}
		instanceName := fmt.Sprintf("%s-%d", instanceBaseName, i)
		log.Info().Msg("weka is not clusterized, creating new instance and clusterizing")
		if err := scale_up.CreateInstance(project, zone, clusterizeTemplate, instanceGroup, instanceName); err != nil {
			fmt.Fprintf(w, "Instance %s creation failed %s", instanceName, err)
		} else {
			fmt.Fprintf(w, "Backend instance %s was created successfully, clusterization has started", instanceName)
		}
		return
	}

	fmt.Fprintf(w, "Nothing to do!")
}

func Terminate(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	collectionName := os.Getenv("COLLECTION_NAME")
	documentName := os.Getenv("DOCUMENT_NAME")
	loadBalancerName := os.Getenv("LOAD_BALANCER_NAME")

	var scaleResponse protocol.ScaleResponse

	if err := json.NewDecoder(r.Body).Decode(&scaleResponse); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}

	terminate.Terminate(w, scaleResponse, project, collectionName, documentName, loadBalancerName)
}

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

func UpdateDb(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	collectionName := os.Getenv("COLLECTION_NAME")
	documentName := os.Getenv("DOCUMENT_NAME")

	var d struct {
		Key   string `json:"key"`
		Value string `json:"value"`
	}

	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}

	var value interface{}
	var err error
	if d.Key == "clusterized" {
		value, err = strconv.ParseBool(d.Value)
		if err != nil {
			fmt.Fprint(w, "Failed decoding request body")
			return
		}
	} else {
		value, err = strconv.ParseInt(d.Value, 10, 64)
		if err != nil {
			fmt.Fprint(w, "Failed decoding request body")
			return
		}
	}

	err = update_db.UpdateValue(project, collectionName, documentName, d.Key, value)
	if err != nil {
		fmt.Fprintf(w, "Updade failed: %s", err)
	} else {
		fmt.Fprintf(w, "Updade completed successfully")
	}
}
