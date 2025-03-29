package weka_api

import (
	"github.com/weka/go-cloud-lib/lib/weka"
)

var validMethods = []weka.JrpcMethod{weka.JrpcStatus}

type WekaApiRequest struct {
	Method weka.JrpcMethod   `json:"method"`
	Params map[string]string `json:"params"`
}

func isSupportedMethod(method weka.JrpcMethod) bool {
	for _, m := range validMethods {
		if method == m {
			return true
		}
	}
	return false
}
