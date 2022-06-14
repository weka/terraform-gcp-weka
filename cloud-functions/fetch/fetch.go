package fetch

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/rs/zerolog/log"
	"google.golang.org/api/iterator"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	"net/http"
	"strings"
)

type HgInstance struct {
	Id        string
	PrivateIp string
}

type HostGroupInfoResponse struct {
	Username        string       `json:"username"`
	Password        string       `json:"password"`
	DesiredCapacity int          `json:"desired_capacity"`
	Instances       []HgInstance `json:"instances"`
	BackendIps      []string     `json:"backend_ips"`
	Role            string       `json:"role"`
	Version         int          `json:"version"`
}

func GetFetchDataParams(project, zone, instanceGroup, clusterName string) HostGroupInfoResponse {

	//creds, err := getUsernameAndPassword(tableName)
	//if err != nil {
	//	return
	//}

	return HostGroupInfoResponse{
		Username:        "username-placeholder",
		Password:        "password-placeholder",
		DesiredCapacity: getCapacity(project, zone, instanceGroup),
		Instances:       getHostGroupInfoInstances(getInstanceGroupInstances(project, zone, instanceGroup)),
		BackendIps:      getBackendsIps(project, zone, clusterName),
		Role:            "backend",
		Version:         1,
	}
}

func getHostGroupInfoInstances(instances []*computepb.Instance) (ret []HgInstance) {
	for _, i := range instances {
		if i.Id != nil && len(i.NetworkInterfaces) > 0 {
			ret = append(ret, HgInstance{
				Id:        fmt.Sprintf("%d", i.Id),
				PrivateIp: *i.NetworkInterfaces[0].NetworkIP,
			})
		}
	}
	return
}

func getCapacity(project, zone, instanceGroup string) int {
	ctx := context.Background()

	c, err := compute.NewInstanceGroupManagersRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
	}
	defer c.Close()

	req := &computepb.GetInstanceGroupManagerRequest{
		Project:              project,
		Zone:                 zone,
		InstanceGroupManager: instanceGroup,
	}

	resp, err := c.Get(ctx, req)
	if err != nil {
		log.Fatal().Err(err)
	}

	return int(*resp.TargetSize)
}

func getInstancesNames(project, zone, instanceGroup string) (instanceNames []string) {
	ctx := context.Background()

	c, err := compute.NewInstanceGroupsRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
	}
	defer c.Close()

	req := &computepb.ListInstancesInstanceGroupsRequest{
		Project:       project,
		Zone:          zone,
		InstanceGroup: instanceGroup,
	}
	it := c.ListInstances(ctx, req)

	for {
		resp, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Fatal().Err(err)
			break
		}
		split := strings.Split(resp.GetInstance(), "/")
		instanceNames = append(instanceNames, split[len(split)-1])
		log.Info().Msgf("%s", split[len(split)-1])
		_ = resp
	}
	return
}

func generateInstanceNamesFilter(instanceNames []string) (namesFilter string) {
	if len(instanceNames) == 0 {
		log.Fatal().Err(errors.New("no instances found in instance group"))
	}

	namesFilter = fmt.Sprintf("name=%s", instanceNames[0])
	for _, instanceName := range instanceNames[1:] {
		namesFilter = fmt.Sprintf("%s OR name=%s", namesFilter, instanceName)
	}
	log.Info().Msgf("%s", namesFilter)
	return
}

func getInstanceGroupInstances(project, zone, instanceGroup string) (instances []*computepb.Instance) {
	namesFilter := generateInstanceNamesFilter(getInstancesNames(project, zone, instanceGroup))

	ctx := context.Background()
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
	}
	defer instanceClient.Close()

	listInstanceRequest := &computepb.ListInstancesRequest{
		Project: project,
		Zone:    zone,
		Filter:  &namesFilter,
	}

	listInstanceIter := instanceClient.List(ctx, listInstanceRequest)

	for {
		resp, err := listInstanceIter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Fatal().Err(err)
			break
		}
		log.Info().Msgf("%s %d %s", *resp.Name, resp.Id, *resp.NetworkInterfaces[0].NetworkIP)
		instances = append(instances, resp)

		_ = resp
	}
	return
}

func getBackendsIps(project, zone, clusterName string) (backendsIps []string) {
	ctx := context.Background()
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
	}
	defer instanceClient.Close()

	clusterNameFilter := fmt.Sprintf("labels.cluster_name=%s", clusterName)
	listInstanceRequest := &computepb.ListInstancesRequest{
		Project: project,
		Zone:    zone,
		Filter:  &clusterNameFilter,
	}

	listInstanceIter := instanceClient.List(ctx, listInstanceRequest)

	for {
		resp, err := listInstanceIter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Fatal().Err(err)
			break
		}
		backendsIps = append(backendsIps, *resp.NetworkInterfaces[0].NetworkIP)

		_ = resp
	}
	return
}

func Fetch(w http.ResponseWriter, r *http.Request) {
	var d struct {
		Project       string `json:"project"`
		Zone          string `json:"zone"`
		InstanceGroup string `json:"instance_group"`
		ClusterName   string `json:"cluster_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}

	fmt.Println("Writing fetch result")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(GetFetchDataParams(d.Project, d.Zone, d.InstanceGroup, d.ClusterName))
}
