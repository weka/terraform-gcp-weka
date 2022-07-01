package increment

import (
	"cloud.google.com/go/firestore"
	"context"
	firebase "firebase.google.com/go"
	"github.com/rs/zerolog/log"
)

func Add(project, collectionName, documentName, instanceName string) (err error) {
	log.Info().Msg("updating DB")

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

	_, err = doc.Update(ctx, []firestore.Update{
		{Path: "instances", Value: firestore.ArrayUnion(instanceName)},
	})

	if err != nil {
		log.Error().Msgf("Failed updating db: %s", err)
	}

	return
}
