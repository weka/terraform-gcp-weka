module github.com/weka/gcp-tf/cloud-functions/scale_up

go 1.16

require (
	cloud.google.com/go/compute v1.6.1
	cloud.google.com/go/firestore v1.6.1 // indirect
	cloud.google.com/go/secretmanager v1.4.0
	firebase.google.com/go v3.13.0+incompatible
	github.com/lithammer/dedent v1.1.0
	github.com/rs/zerolog v1.27.0
	google.golang.org/api v0.84.0
	google.golang.org/genproto v0.0.0-20220615141314-f1464d18c36b
	google.golang.org/protobuf v1.28.0
)
