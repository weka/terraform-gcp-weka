module github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions

go 1.16

require (
	cloud.google.com/go/compute v1.5.0
	cloud.google.com/go/secretmanager v1.4.0
	cloud.google.com/go/storage v1.10.0
	github.com/google/uuid v1.1.2
	github.com/lithammer/dedent v1.1.0
	github.com/rs/zerolog v1.27.0
	golang.org/x/oauth2 v0.0.0-20220309155454-6242fa91716a
	google.golang.org/api v0.74.0
	google.golang.org/genproto v0.0.0-20220405205423-9d709892a2bf
	google.golang.org/protobuf v1.28.0
)
