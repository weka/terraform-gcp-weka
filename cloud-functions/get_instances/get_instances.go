package get_instances

import (
	"context"
	firebase "firebase.google.com/go"
	"fmt"
	"github.com/rs/zerolog/log"
	"strings"
)

func GetInstances(project, collectionName, documentName string) (instances []string) {
	log.Info().Msg("Retrieving desired group size from DB")

	ctx := context.Background()
	conf := &firebase.Config{ProjectID: project}
	app, err := firebase.NewApp(ctx, conf)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	client, err := app.Firestore(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer client.Close()
	doc := client.Collection(collectionName).Doc(documentName)
	res, err := doc.Get(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	instancesInterfaces := res.Data()["instances"].([]interface{})
	for _, v := range instancesInterfaces {
		instances = append(instances, v.(string))
	}

	return
}

func GetInstancesBashList(project, collectionName, documentName string) string {
	return fmt.Sprintf("(\"%s\")", strings.Join(GetInstances(project, collectionName, documentName), "\" \""))
}
