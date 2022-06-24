package get_db_value

import (
	"context"
	firebase "firebase.google.com/go"
	"fmt"
	"github.com/rs/zerolog/log"
	"net/http"
	"os"
)

func getValue(project, collectionName, documentName string) (info map[string]interface{}) {
	log.Debug().Msg("Retrieving value from DB")

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
	return res.Data()

}

func GetDbValue(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	collectionName := os.Getenv("COLLECTION_NAME")
	documentName := os.Getenv("DOCUMENT_NAME")

	clusterInfo := getValue(project, collectionName, documentName)
	counter := clusterInfo["counter"].(int64)

	fmt.Fprintf(w, "%d", counter)
}
