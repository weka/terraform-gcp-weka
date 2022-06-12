package jrpc

import (
	"context"
	"errors"
	"fmt"
	"github.com/weka/gcp-tf/cloud-functions/scale/lib/jsonrpc2"
	"golang.org/x/oauth2"
	"net/http"
	"net/url"
	"time"
)

var ErrNoCredentials = errors.New("no credentials provided")

// tokenSource is a source that always does a user_login / user_refresh_token if a refresh token is availble JSONRPC request for a new token.
// It should be wrapped with a ReuseTokenSource.
type tokenSource struct {
	ctx      context.Context
	log      logger
	endpoint *url.URL

	userName     string
	password     string
	refreshToken string
}

func (ts *tokenSource) Token() (*oauth2.Token, error) {
	ctx, cancel := context.WithCancel(ts.ctx)
	defer cancel()
	httpClient := ts.ctx.Value(oauth2.HTTPClient).(*http.Client)
	conn := jsonrpc2.NewConn(newHTTPObjectStream(ts.endpoint, httpClient.Transport, ts.log))
	conn.AddHandler(logHandler{ep: ts.endpoint, log: ts.log})
	go conn.Run(ctx)

	var tok struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		ExpiresInSec int    `json:"expires_in"`
		TokenType    string `json:"token_type"`
	}

	// apiCallTime := time.Now()
	var err error
	if ts.refreshToken == "" {
		if ts.userName == "" && ts.password == "" {
			return nil, ErrNoCredentials
		}
		err = conn.Call(ctx, "user_login", []string{ts.userName, ts.password}, &tok)
	} else {
		err = conn.Call(ctx, "user_refresh_token", []string{ts.refreshToken}, &tok)
	}
	now := time.Now()
	if err != nil {
		var badStatusErr *BadHTTPRespnoseError
		if errors.As(err, &badStatusErr) && badStatusErr.Response != nil && badStatusErr.Response.StatusCode == http.StatusUnauthorized {
			return nil, &oauth2.RetrieveError{
				Response: badStatusErr.Response,
				Body:     badStatusErr.Body,
			}
		}
		return nil, fmt.Errorf("tokenSource failed to acquire token: %w", err)
	}

	// claims, err := Decode(tok.AccessToken)
	// if err != nil {
	// 	log.Fatal(err)
	// }
	// jwtIssuedTime := time.Unix(claims.Iat, 0)
	// jwtExpireTime := time.Unix(claims.Exp, 0)

	result := &oauth2.Token{
		AccessToken:  tok.AccessToken,
		RefreshToken: tok.RefreshToken,
		TokenType:    tok.TokenType,
		Expiry:       now.Add(time.Duration(tok.ExpiresInSec) * time.Second),
	}
	ts.refreshToken = tok.RefreshToken

	// log.Printf("Token: %+v\njwtIssuedTime: %s\njwtExpireTime: %s\nExpiresInSec is %d", result, jwtIssuedTime, jwtExpireTime, tok.ExpiresInSec)
	return result, nil
}

// // copied from jws because we use an object in Sub instead of email

// // ClaimSet contains information about the JWT signature including the
// // permissions being requested (scopes), the target of the token, the issuer,
// // the time the token was issued, and the lifetime of the token.
// type ClaimSet struct {
// 	Iss   string `json:"iss"`             // email address of the client_id of the application making the access token request
// 	Scope string `json:"scope,omitempty"` // space-delimited list of the permissions the application requests
// 	Aud   string `json:"aud"`             // descriptor of the intended target of the assertion (Optional).
// 	Exp   int64  `json:"exp"`             // the expiration time of the assertion (seconds since Unix epoch)
// 	Iat   int64  `json:"iat"`             // the time the assertion was issued (seconds since Unix epoch)
// 	Typ   string `json:"typ,omitempty"`   // token type (Optional).

// 	// Email for which the application is requesting delegated access (Optional).
// 	//Sub string `json:"sub,omitempty"`
// 	Sub map[string]interface{} `json:"sub,omitempty"`

// 	// The old name of Sub. Client keeps setting Prn to be
// 	// complaint with legacy OAuth 2.0 providers. (Optional)
// 	Prn string `json:"prn,omitempty"`

// 	// See http://tools.ietf.org/html/draft-jones-json-web-token-10#section-4.3
// 	// This array is marshalled using custom code (see (c *ClaimSet) encode()).
// 	PrivateClaims map[string]interface{} `json:"-"`
// }

// // Decode decodes a claim set from a JWS payload.
// func Decode(payload string) (*ClaimSet, error) {
// 	// decode returned id token to get expiry
// 	s := strings.Split(payload, ".")
// 	if len(s) < 2 {
// 		// TODO(jbd): Provide more context about the error.
// 		return nil, errors.New("jws: invalid token received")
// 	}
// 	decoded, err := base64.RawURLEncoding.DecodeString(s[1])
// 	if err != nil {
// 		return nil, err
// 	}
// 	c := &ClaimSet{}
// 	err = json.NewDecoder(bytes.NewBuffer(decoded)).Decode(c)
// 	return c, err
// }
