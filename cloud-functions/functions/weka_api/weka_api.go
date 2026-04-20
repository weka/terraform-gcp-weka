package weka_api

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
)

func RunWekaApi(ctx context.Context, wr *WekaApiRequest) (json.RawMessage, error) {
	log.Info().Msg("RunWekaApi> ")
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	usernameId := os.Getenv("USER_NAME_ID")
	adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
	deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")

	if !isSupportedMethod(wr.Method) {
		return nil, fmt.Errorf("weka api method %s is not supported", wr.Method)
	}

	jpool, err := common.GetWekaJrpcPool(ctx, project, zone, instanceGroup, usernameId, deploymentPasswordId, adminPasswordId)
	if err != nil {
		log.Error().Msgf("failed to get jrpc pool %w", err)
		return nil, fmt.Errorf("failed to get jrpc pool %w", err)
	}

	var params interface{}
	if wr.Params != nil {
		params = wr.Params
	} else {
		params = struct{}{}
	}
	var rawWekaStatus json.RawMessage

	err = jpool.Call(wr.Method, params, &rawWekaStatus)
	if err != nil {
		log.Error().Msgf("failed to call jrpc %w", err)
		return nil, fmt.Errorf("failed to call jrpc %w", err)
	}

	log.Info().Msgf("received %v", rawWekaStatus)

	return rawWekaStatus, nil
}
