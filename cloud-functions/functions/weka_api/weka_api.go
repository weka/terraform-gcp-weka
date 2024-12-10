package weka_api

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/lib/weka"
)

type WekaApiRequest struct {
	Method  string            `json:"method"`
	Payload map[string]string `json:"payload"`
}

func RunWekaApi(ctx context.Context, wr *WekaApiRequest) (interface{}, error) {
	log.Info().Msg("RunWekaApi> ")
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	usernameId := os.Getenv("USER_NAME_ID")
	adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
	deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")

	jpool, err := common.GetWekaJrpcPool(ctx, project, zone, instanceGroup, usernameId, deploymentPasswordId, adminPasswordId)
	if err != nil {
		log.Error().Msgf("failed to get jrpc pool %w", err)
		return nil, fmt.Errorf("failed to get jrpc pool %w", err)
	}

	log.Info().Msgf("RunWekaApi> ips list %v", jpool.Ips)

	var rawWekaStatus json.RawMessage
	var jrpcMethod weka.JrpcMethod
	switch wr.Method {
	case "status":
		jrpcMethod = weka.JrpcStatus
	default:
		return nil, fmt.Errorf("weka api method %s is not supported", wr.Method)
	}

	err = jpool.Call(jrpcMethod, struct{}{}, &rawWekaStatus)
	if err != nil {
		log.Error().Msgf("failed to call jrpc %w", err)
		return nil, fmt.Errorf("failed to call jrpc %w", err)
	}

	log.Info().Msgf("received %v", rawWekaStatus)

	return rawWekaStatus, nil
}
