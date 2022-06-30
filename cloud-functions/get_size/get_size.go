package get_size

import (
	"context"
	firebase "firebase.google.com/go"
	"github.com/rs/zerolog/log"
)

func GetSize(project, collectionName, documentName string) int {
	log.Info().Msg("Retrieving desired group size from DB")

	ctx := context.Background()
	conf := &firebase.Config{ProjectID: project}
	app, err := firebase.NewApp(ctx, conf)
	if err != nil {
		log.Error().Msgf("%s", err)
		return -1
	}

	client, err := app.Firestore(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return -1
	}
	defer client.Close()
	doc := client.Collection(collectionName).Doc(documentName)
	res, err := doc.Get(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return -1
	}
	return len(res.Data()["instances"].([]interface{}))
}
