package jrpc

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/weka/gcp-tf/cloud-functions/scale/lib/jsonrpc2"
	"io"
	"io/ioutil"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strconv"
	"time"

	"golang.org/x/oauth2"
)

type BadHTTPRespnoseError struct {
	Response *http.Response
	Body     []byte
}

func (b *BadHTTPRespnoseError) Error() string {
	return "bad HTTP response: " + strconv.Itoa(b.Response.StatusCode)
}

type Error struct {
	Endpoint   *url.URL
	ClientType string
	Method     string
	Err        error
}

func (e *Error) Error() string {
	return fmt.Sprintf("jrpc error %s#%s.%s: %v", e.Endpoint.String(), e.ClientType, e.Method, e.Err)
}

func (e *Error) Unwrap() error {
	return e.Err
}

type ctxKeyType int

const (
	idempotentCallKey     = ctxKeyType(1)
	overrideReqTimeoutKey = ctxKeyType(2)
)

type logger interface {
	Printf(format string, v ...interface{})
}

// MarkCallIdempotent is used for signaling jsonrpc2.Conn Call/Notify methods it's safe to retry on connection errors.
func MarkCallIdempotent(ctx context.Context) context.Context {
	return context.WithValue(ctx, idempotentCallKey, true)
}

// OverrideReqTimeout is used for signaling BasicClient Call/Notify methods to use the specified request timeout
// instead of the default one.
func OverrideReqTimeout(ctx context.Context, timeout time.Duration) context.Context {
	return context.WithValue(ctx, overrideReqTimeoutKey, timeout)
}

// httpStream implements jsonrpc2.Stream over http POST requests.
type httpStream struct {
	log      logger
	endpoint *url.URL
	rt       http.RoundTripper
	buf      [1024]byte
	replies  chan *io.PipeReader
}

func newHTTPObjectStream(u *url.URL, rt http.RoundTripper, l logger) *httpStream {
	stream := &httpStream{
		log:      l,
		endpoint: u,
		rt:       rt,
		replies:  make(chan *io.PipeReader, 1),
	}
	return stream
}

func (h *httpStream) transport() http.RoundTripper {
	if h.rt == nil {
		return http.DefaultTransport
	}
	return h.rt
}

func (h *httpStream) Write(ctx context.Context, b []byte) (int64, error) {
	payload := bytes.NewReader(b)
	idemp, _ := ctx.Value(idempotentCallKey).(bool)
	makeRequest := func() (*http.Request, error) {
		payload.Reset(b)
		req, err := http.NewRequestWithContext(
			/*
				httptrace.WithClientTrace(ctx,
					&httptrace.ClientTrace{
						ConnectStart: func(network, addr string) {
							h.log.Printf("\tXXX begin dialing %s:%s", network, addr)
						},
						ConnectDone: func(network, addr string, err error) {
							h.log.Printf("\tXXX finished dialing %s:%s (%v)", network, addr, err)
						},
						GotConn: func(info httptrace.GotConnInfo) {
							h.log.Printf("\tXXX info: %+v", info)
						},
						PutIdleConn: func(err error) {
							h.log.Printf("\tXXX puting connection into idle pool %v", err)
						},
						WroteHeaderField: func(key string, value []string) {
							h.log.Printf("\tXXX HTTP header: %s = %v", key, value)
						}}),
			*/
			ctx,
			http.MethodPost, h.endpoint.String(), payload)
		if err != nil {
			return nil, err
		}

		if idemp {
			// https://golang.org/pkg/net/http/#Transport
			// If the idempotency key value is an zero-length slice, the request is treated as idempotent but the header is not sent on the wire.
			req.Header["X-Idempotency-Key"] = []string{}
		}
		return req, nil
	}

	req, err := makeRequest()
	if err != nil {
		return 0, fmt.Errorf("httpStream.WriteObject: NewRequest failed: %w", err)
	}

	// https://www.simple-is-better.org/json-rpc/transport_http.html#post-request
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	for {
		if ctx.Err() != nil {
			return 0, ctx.Err()
		}

		resp, err := h.transport().RoundTrip(req)
		if err != nil {
			var rErr *oauth2.RetrieveError
			if errors.As(err, &rErr) {
				return 0, rErr
			}
			return 0, fmt.Errorf("POST failed: %w", err)
		}
		closeResp := func() {
			io.Copy(ioutil.Discard, resp.Body)
			resp.Body.Close()
		}
		defer closeResp()

		switch resp.StatusCode {
		case http.StatusOK, http.StatusCreated, http.StatusAccepted:
			r, w := io.Pipe()
			defer w.Close()
			select {
			case h.replies <- r:
				return io.CopyBuffer(w, resp.Body, h.buf[:])

			case <-ctx.Done():
				return int64(len(b)), ctx.Err()
			}
		// TODO: http.StatusInternalServerError is not something we should retry on, but we do it here to workaround
		// errors in upgrade until we resolve WEKAPP-155399
		case http.StatusServiceUnavailable, http.StatusBadGateway, http.StatusInternalServerError:
			h.log.Printf("httpStream.WriteObject: HTTP response %d from %v, retrying", resp.StatusCode, req.URL)

			closeResp()
			// RoundTripper.RoundTrip: Callers should not mutate or reuse the request until the Response's Body has been closed.
			// Can't safely reset a req for retry.
			// https://github.com/golang/go/issues/26408
			// https://github.com/golang/go/issues/26409
			req, err = makeRequest()
			if err != nil {
				return 0, fmt.Errorf("httpStream.WriteObject: NewRequest failed: %w", err)
			}

			// TODO: this wait should be configurable
			time.Sleep(time.Second)
			continue

		default:
			var buf bytes.Buffer
			bytesResp, err := httputil.DumpResponse(resp, true /*body*/)
			if err != nil {
				buf.WriteString(fmt.Sprintf("can't dump response %v: %v", resp, err))
				bytesResp = buf.Bytes()
			}
			h.log.Printf("httpStream.WriteObject: bad HTTP response %d from %v:\n%q", resp.StatusCode, req.URL, string(bytesResp))
			buf.Reset()
			io.CopyBuffer(&buf, resp.Body, h.buf[:])
			return int64(len(b)), &BadHTTPRespnoseError{Response: resp, Body: buf.Bytes()}
		}
	}
}

func (h *httpStream) Read(ctx context.Context) ([]byte, int64, error) {
	select {
	case r := <-h.replies:
		var buf bytes.Buffer
		n, err := buf.ReadFrom(r)
		// h.log.Printf("ReadObject got: %s", buf.String())
		return buf.Bytes(), n, err

	case <-ctx.Done():
		return nil, 0, ctx.Err()
	}
}

func (h *httpStream) Close() error {
	close(h.replies)
	if t, ok := h.rt.(*http.Transport); ok {
		t.CloseIdleConnections()
	}
	return nil
}

type credentials struct {
	Username     string
	Password     string
	RefreshToken string
}

type ClientOptions struct {
	authed bool
	creds  credentials

	requestTimeout time.Duration
}

func (opt *ClientOptions) AuthenticatedClient(username, password, refreshToken string) *ClientOptions {
	opt.authed = true
	opt.creds = credentials{Username: username, Password: password, RefreshToken: refreshToken}
	return opt
}

func (opt *ClientOptions) RequestTimeout(timeout time.Duration) *ClientOptions {
	opt.requestTimeout = timeout
	return opt
}

type BaseClient struct {
	*jsonrpc2.Conn
	log            logger
	endpoint       *url.URL
	rt             http.RoundTripper
	requestTimeout time.Duration
	cancelFn       context.CancelFunc
}

// override jsonrpc2.Conn.Call
func (c *BaseClient) Call(ctx context.Context, method string, params, result interface{}) (err error) {
	timeout, ok := ctx.Value(overrideReqTimeoutKey).(time.Duration)
	if !ok {
		timeout = c.requestTimeout
	}
	if timeout <= 0 {
		return c.Conn.Call(ctx, method, params, result)
	}
	reqCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	return c.Conn.Call(reqCtx, method, params, result)
}

// override jsonrpc2.Conn.Notify
func (c *BaseClient) Notify(ctx context.Context, method string, params interface{}) (err error) {
	timeout, ok := ctx.Value(overrideReqTimeoutKey).(time.Duration)
	if !ok {
		timeout = c.requestTimeout
	}
	if timeout <= 0 {
		return c.Conn.Notify(ctx, method, params)
	}
	reqCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	return c.Conn.Notify(reqCtx, method, params)
}

func NewClient(ctx context.Context, l logger, u *url.URL, rt http.RoundTripper, opt *ClientOptions) *BaseClient {
	ctx, cancelFn := context.WithCancel(ctx)
	var conn *jsonrpc2.Conn
	if opt.authed {
		conn = newAuthenticatedConn(ctx, u, rt, l, &opt.creds, opt.requestTimeout)
	} else {
		conn = newConn(ctx, u, rt, l)
	}
	go conn.Run(ctx)
	return &BaseClient{
		Conn:           conn,
		log:            l,
		endpoint:       u,
		rt:             rt,
		requestTimeout: opt.requestTimeout,
		cancelFn:       cancelFn,
	}
}

func newAuthenticatedConn(ctx context.Context, u *url.URL, rt http.RoundTripper, l logger, cred *credentials, oauth2ClientTimeout time.Duration) *jsonrpc2.Conn {
	// make oauth2 use the Transport rt.
	// We need this step because oauth2.NewClient only uses the oauth2.HTTPClient key for the wrapped authorized Transport, not any other http.Client settings.
	// See https://github.com/golang/oauth2/issues/368
	ctx = context.WithValue(ctx, oauth2.HTTPClient, &http.Client{Transport: rt, Timeout: oauth2ClientTimeout})
	oauthClient := oauth2.NewClient(ctx, oauth2.ReuseTokenSource(nil, &tokenSource{ctx, l, u, cred.Username, cred.Password, cred.RefreshToken}))
	return newConn(ctx, u, oauthClient.Transport, l)
}

func newConn(ctx context.Context, u *url.URL, rt http.RoundTripper, l logger) *jsonrpc2.Conn {
	conn := jsonrpc2.NewConn(newHTTPObjectStream(u, rt, l))
	conn.AddHandler(logHandler{ep: u, log: l})
	return conn
}

func (c *BaseClient) Endpoint() *url.URL {
	return c.endpoint
}

func (c *BaseClient) Close() error {
	c.cancelFn()
	return nil
}

type logHandler struct {
	jsonrpc2.EmptyHandler
	ep  *url.URL
	log logger
}

func (h logHandler) Request(ctx context.Context, conn *jsonrpc2.Conn, direction jsonrpc2.Direction, r *jsonrpc2.WireRequest) context.Context {
	paramBytes, err := json.Marshal(r.Params)
	if err != nil {
		paramBytes = []byte(fmt.Sprintf("error in json.Marshal of parameters: %v", err))
	}
	h.log.Printf("--(%s: %v)--> %s %s", h.ep.String(), r.ID, r.Method, string(paramBytes))
	return ctx
}

func (h logHandler) Response(ctx context.Context, conn *jsonrpc2.Conn, direction jsonrpc2.Direction, r *jsonrpc2.WireResponse) context.Context {
	h.log.Printf("<--(%s: %v)-- %v", h.ep.String(), r.ID, r.Error)
	return ctx
}
