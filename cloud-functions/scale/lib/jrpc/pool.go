package jrpc

import (
	"context"
	"github.com/rs/zerolog/log"
	strings2 "github.com/weka/gcp-tf/cloud-functions/scale/lib/strings"
	"github.com/weka/gcp-tf/cloud-functions/scale/lib/weka"
	"sync"
)

type ClientBuilder func(ip string) *BaseClient
type Pool struct {
	sync.RWMutex
	Ips     []string
	Clients map[string]*BaseClient
	Active  string
	Builder ClientBuilder
	Ctx     context.Context
}

func (c *Pool) Drop(toDrop string) {
	log.Debug().Msgf("dropping %s from pool", toDrop)
	c.Lock()
	defer c.Unlock()
	if c.Active == toDrop {
		c.Active = ""
	}

	for i, ip := range c.Ips {
		if ip == toDrop {
			c.Ips[i] = c.Ips[len(c.Ips)-1]
			c.Ips = c.Ips[:len(c.Ips)-1]
			break
		}
	}
}

func (c *Pool) Call(method weka.JrpcMethod, params, result interface{}) (err error) {
	if c.Active == "" {
		c.Lock()
		c.Active = c.Ips[0]
		c.Clients[c.Active] = c.Builder(c.Active)
		c.Unlock()
	}
	err = c.Clients[c.Active].Call(c.Ctx, string(method), params, result)
	if err != nil {
		if strings2.AnyOfSubstr(err.Error(), "connection refused", "context deadline exceeded", "Method not found", "tokenSource failed to acquire token") {
			c.Drop(c.Active)
			return c.Call(method, params, result)
		} else {
			return err
		}
	}
	return nil
}
