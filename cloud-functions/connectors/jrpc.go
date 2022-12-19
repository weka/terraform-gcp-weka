package connectors

import (
	"context"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/lib/jrpc"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

type jrpcLogger struct {
}

func (j *jrpcLogger) Printf(format string, v ...interface{}) {
	log.Debug().Msgf(format, v...)
}

func NewJrpcClient(ctx context.Context, host string, port int, username string, password string) *jrpc.BaseClient {
	opt := jrpc.ClientOptions{}
	opt.AuthenticatedClient(username, password, "")
	opt.RequestTimeout(3 * time.Second)

	return jrpc.NewClient(
		ctx, &jrpcLogger{}, &url.URL{
			Scheme: "http",
			Host:   net.JoinHostPort(host, strconv.Itoa(port)),
			Path:   "/api/v1",
		},
		&http.Transport{
			DialContext: (&net.Dialer{
				Timeout:       time.Second * 5,
				KeepAlive:     time.Second,
				FallbackDelay: time.Duration(-1), /* disable dual-stack IPv6 first */
			}).DialContext,

			MaxIdleConnsPerHost: 1,
			IdleConnTimeout:     time.Second,
		}, &opt,
	)
}
