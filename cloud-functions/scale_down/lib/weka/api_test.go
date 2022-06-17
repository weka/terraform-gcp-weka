package weka

import (
	"encoding/json"
	"testing"
)

func TestHostListJson(t *testing.T) {
	input := []byte(`{"HostId<9>": {
    "mode": "backend",
    "failure_domain_id": "FailureDomainId<1>",
    "bandwidth": 6497,
    "failure_domain": "DOM-009",
    "added_time": "2021-01-12T09:28:53.407011Z",
    "drives_dedicated_cores": 0,
    "hostname": "asgt-9",
    "ips": [
      "172.31.35.245"
    ],
    "member_of_leadership": false,
    "io_nodes": 1,
    "last_failure_time": "2021-01-12T09:28:44.582728Z",
    "state": "ACTIVE",
    "start_time": "2021-01-12T09:28:45.211962Z",
    "aws": {
      "instance_type": "i3.large",
      "availability_zone": "eu-central-1c",
      "instance_id": "i-0c7f50cad78e1658e"
    },
    "sw_version": "3.11.1.1856",
    "os_info": {
      "kernel_name": "Linux",
      "platform": "x86_64",
      "kernel_version": "#1 SMP Tue Mar 17 23:49:17 UTC 2020",
      "os_name": "GNU/Linux",
      "kernel_release": "3.10.0-1062.18.1.el7.x86_64",
      "drivers": {
        "ixgbe": "",
        "ixgbevf": "",
        "mlx5_core": "",
        "ib_uverbs": "",
        "uio_pci_generic": "5f49bb7dc1b5d192fb01b442b17ddc0451313ea2"
      }
    },
    "last_failure_code": "ApplyingResources",
    "cores_ids": [
      1
    ],
    "frontend_dedicated_cores": 0,
    "memory": 1491075072,
    "failure_domain_type": "USER",
    "leadership_role": null,
    "state_changed_time": null,
    "status": "UP",
    "cores": 1,
    "host_ip": "172.31.35.245",
    "is_dedicated": false,
    "last_failure": "Applying resources on container",
    "mgmt_port": 14000,
    "auto_remove_timeout": null
  }
}`)

	response := HostListResponse{}
	err := json.Unmarshal(input, &response)
	if err != nil {
		t.Error(err)
	}
	if response[HostId{
		hostId:     9,
		wekaHostId: "HostId<9>",
	}].State != "ACTIVE" {
		t.Fail()
	}
}

func TestDriveListUnmarshalling(t *testing.T) {
	input := []byte(`{"DiskId<8>": {
    "model": "Amazon EC2 NVMe Instance Storage",
    "removed_time": null,
    "spares_remaining": 100,
    "node_id": "NodeId<81>",
    "firmware": "0",
    "serial_number": "AWS2738160EC638B1C72",
    "failure_domain": "FailureDomainId<4>",
    "uuid": "d5c36ee4-22b5-42b2-a723-f3aa2938da55",
    "device_path": "0000:00:1e.0",
    "attachment": "OK",
    "should_be_active": true,
    "size_bytes": 474998934528,
    "hostname": "asgt2-4",
    "percentage_used": 0,
    "vendor": "AMAZON",
    "block_size": 512,
    "added_time": "2021-01-12T15:56:00.573654Z",
    "spares_threshold": 0,
    "host_id": "HostId<4>",
    "failure_domain_name": "DOM-004",
    "status": "ACTIVE"
  }}`)

	response := DriveListResponse{}
	err := json.Unmarshal(input, &response)
	if err != nil {
		t.Error(err)
	}

	if response[DriveId{
		driveId:     8,
		wekaDriveId: "DiskId<8>",
	}].Status != "ACTIVE" {
		t.Fail()
	}
}
