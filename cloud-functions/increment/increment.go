package increment

import (
	"cloud.google.com/go/firestore"
	"context"
	firebase "firebase.google.com/go"
	"fmt"
	"github.com/rs/zerolog/log"
	"net/http"
	"os"
)

func increment(project, collectionName, documentName string) (err error) {
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
		{Path: "counter", Value: firestore.Increment(1)},
	})

	if err != nil {
		log.Error().Msgf("Failed updating db: %s", err)
	}

	return
}

func Increment(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	collectionName := os.Getenv("COLLECTION_NAME")
	documentName := os.Getenv("DOCUMENT_NAME")

	err := increment(project, collectionName, documentName)
	if err != nil {
		fmt.Fprintf(w, "Increment failed: %s", err)
	} else {
		fmt.Fprintf(w, "Increment completed successfully")
	}
}
