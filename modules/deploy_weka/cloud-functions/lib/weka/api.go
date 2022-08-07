package weka

import (
	"github.com/google/uuid"
	"time"
)

type JrpcMethod string

const (
	JrpcHostList         JrpcMethod = "hosts_list"
	JrpcNodeList         JrpcMethod = "nodes_list"
	JrpcDrivesList       JrpcMethod = "disks_list"
	JrpcRemoveDrive      JrpcMethod = "cluster_remove_drives"
	JrpcRemoveHost       JrpcMethod = "cluster_remove_host"
	JrpcDeactivateDrives JrpcMethod = "cluster_deactivate_drives"
	JrpcDeactivateHosts  JrpcMethod = "cluster_deactivate_hosts"
	JrpcStatus           JrpcMethod = "status"
	JrpcRebuildStatus    JrpcMethod = "system_get_rebuild_status"
)

type HostListResponse map[HostId]Host
type DriveListResponse map[DriveId]Drive
type NodeListResponse map[NodeId]Node

type StatusResponse struct {
	IoStatus string `json:"io_status"`
	Upgrade  string `json:"upgrade"`
}

type Host struct {
	AddedTime        time.Time `json:"added_time"`
	StateChangedTime time.Time `json:"state_changed_time"`
	State            string    `json:"state"`
	Status           string    `json:"status"`
	HostIp           string    `json:"host_ip"`
	Aws              struct {
		InstanceId string `json:"instance_id"`
	} `json:"aws"`
}

type Drive struct {
	HostId         HostId    `json:"host_id"`
	Status         string    `json:"status"`
	Uuid           uuid.UUID `json:"uuid"`
	ShouldBeActive bool      `json:"should_be_active"`
}

type Node struct {
	LastFencingTime *time.Time `json:"last_fencing_time"`
	Status          string     `json:"status"`
	UpSince         *time.Time `json:"up_since"`
	HostId          HostId     `json:"host_id"`
}

type Protection map[string]interface{}
type RebuildStatus struct {
	EnoughActiveFDs       bool         `json:"enoughActiveFDs"`
	IsInited              bool         `json:"isInited"`
	NumActiveFDs          int          `json:"numActiveFDs"`
	ProgressPercent       float32      `json:"progressPercent"`
	ProtectionState       []Protection `json:"protectionState"`
	RequiredFDsForRebuild int          `json:"requiredFDsForRebuild"`
	StripeDisks           int          `json:"stripeDisks"`
	TotalCopiesDoneMiB    int          `json:"totalCopiesDoneMiB"`
	TotalCopiesMiB        int          `json:"totalCopiesMiB"`
	UnavailableMiB        int          `json:"unavailableMiB"`
	UnavailablePercent    int          `json:"unavailablePercent"`
}
