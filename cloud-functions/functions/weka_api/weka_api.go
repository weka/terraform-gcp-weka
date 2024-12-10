package weka_api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/lib/weka"
)

type WekaApi struct {
}

func RunWekaApi(r *http.Request) (interface{}, error) {
	log.Info().Msg("RunWekaApi> ")
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	bucket := os.Getenv("BUCKET")
	stateObject := os.Getenv("STATE_OBJ_NAME")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	usernameId := os.Getenv("USER_NAME_ID")
	adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
	deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")

	log.Info().Msgf("instance group %v", instanceGroup)
	// nfsStateObject := os.Getenv("NFS_STATE_OBJ_NAME")
	// nfsInstanceGroup := os.Getenv("NFS_INSTANCE_GROUP")

	ctx := r.Context()

	state, err := common.GetClusterState(ctx, bucket, stateObject)
	if err != nil {
		log.Error().Msgf("failed to get cluster state %v", err)
		return nil, err
	}
	log.Info().Msgf("got state %v", state)

	var requestBody struct {
		Type     string `json:"type"`
		Protocol string `json:"protocol"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		return nil, fmt.Errorf("failed to decode request %w", err)
	}
	log.Info().Msgf("request body %v", requestBody)

	// jpool, err := common.GetWekaJrpcPool(ctx, project, zone, instanceGroup, usernameId, deploymentPasswordId, adminPasswordId)
	jpool, err := common.GetWekaJrpcPool(ctx, project, zone, instanceGroup, usernameId, deploymentPasswordId, adminPasswordId)
	if err != nil {
		log.Error().Msgf("failed to get jrpc pool %w", err)
		return nil, fmt.Errorf("failed to get jrpc pool %w", err)
	}

	log.Info().Msgf("RunWekaApi> ips list %v", jpool.Ips)

	var rawWekaStatus json.RawMessage

	err = jpool.Call(weka.JrpcStatus, struct{}{}, &rawWekaStatus)
	if err != nil {
		log.Error().Msgf("failed to call jrpc %w", err)
		return nil, fmt.Errorf("failed to call jrpc %w", err)
	}

	log.Info().Msgf("received %v", rawWekaStatus)
	// switch requestBody.Type {

	// }
	return rawWekaStatus, nil
}
