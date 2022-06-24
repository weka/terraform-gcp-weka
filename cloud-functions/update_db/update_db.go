package update_db

import (
	"cloud.google.com/go/firestore"
	"context"
	"encoding/json"
	firebase "firebase.google.com/go"
	"fmt"
	"github.com/rs/zerolog/log"
	"net/http"
	"os"
	"strconv"
)

func updateValue(project, collectionName, documentName, key string, value interface{}) (err error) {
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
		{Path: key, Value: value},
	})
	if err != nil {
		log.Error().Msgf("Failed updating db: %s", err)
	}

	return
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

	err = updateValue(project, collectionName, documentName, d.Key, value)
	if err != nil {
		fmt.Fprintf(w, "Updade failed: %s", err)
	} else {
		fmt.Fprintf(w, "Updade completed successfully")
	}
}
