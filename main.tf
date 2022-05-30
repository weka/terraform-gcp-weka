resource "google_compute_network" "vpc_network" {
  count                   = var.nics_number
  name                    = "${var.prefix}-vpc-${count.index}"
  auto_create_subnetworks = false
  mtu                     = 1460
}

# ======================= subnet ==========================
locals {
  temp         = flatten([
  for from in range(length(google_compute_network.vpc_network)) : [
  for to in range(length(google_compute_network.vpc_network)) : {
    from = from
    to   = to
  }
  ]
  ])
  peering-list = [for t in local.temp : t if t["from"] != t["to"]]
}

resource "google_compute_subnetwork" "subnetwork" {
  count         = length(google_compute_network.vpc_network)
  name          = "${var.prefix}-subnet-${count.index}"
  ip_cidr_range = var.subnets[count.index]
  region        = var.region
  network       = google_compute_network.vpc_network[count.index].name
}

resource "google_compute_network_peering" "peering" {
  count        = length(local.peering-list)
  name         = "${var.prefix}-peering-${local.peering-list[count.index]["from"]}-${local.peering-list[count.index]["to"]}"
  network      = google_compute_network.vpc_network[local.peering-list[count.index]["from"]].self_link
  peer_network = google_compute_network.vpc_network[local.peering-list[count.index]["to"]].self_link
}

# ======================== ssh-key ============================
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_private_key_pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = var.private_key_filename
  file_permission = "0600"
}

resource "google_compute_firewall" "sg" {
  count         = length(google_compute_network.vpc_network)
  name          = "${var.prefix}-sg-ssh-${count.index}"
  network       = google_compute_network.vpc_network[count.index].name
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_tags   = ["ssh"]
}

resource "google_compute_firewall" "sg_private" {
  count         = length(google_compute_network.vpc_network)
  name          = "${var.prefix}-ag-all-${count.index}"
  network       = google_compute_network.vpc_network[count.index].name
  source_ranges = ["10.0.0.0/8"]
  allow {
    protocol = "all"
  }
  source_tags   = ["all"]
}


# ======================== instance ============================
resource "google_compute_instance" "compute" {
  count        = var.cluster_size
  name         = "${var.prefix}-compute-${count.index}"
  machine_type = var.machine_type
  zone         = "${var.region}-a"
  tags         = ["${var.prefix}-compute"]

  metadata = {
    ssh-keys = "${var.username}:${tls_private_key.ssh.public_key_openssh}"
  }

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      size  = 50
    }
  }

  dynamic "scratch_disk" {
    for_each = range(var.nvmes_number)
    content {
      interface = "NVME"
    }
  }

  # nic with public ip
  network_interface {
    subnetwork = google_compute_subnetwork.subnetwork[0].name
    access_config {}
  }

  # nics with private ip
  dynamic "network_interface" {
    for_each = range(1, var.nics_number)
    content {
      subnetwork = google_compute_subnetwork.subnetwork[network_interface.value].name
    }
  }

  metadata_startup_script = <<-EOT
    # https://gist.github.com/fungusakafungus/1026804
    function retry {
        local retry_max=$1
        local retry_sleep=$2
        shift 2

        local count=$retry_max
        while [ $count -gt 0 ]; do
            "$@" && break
            count=$(($count - 1))
            sleep $retry_sleep
        done

        [ $count -eq 0 ] && {
            echo "Retry failed [$retry_max]: $@"
            return 1
        }
        return 0
    }

  retry 300 2 curl --fail --max-time 10 https://${var.get_weka_io_token}@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}| sh
 EOT
}

# ======================== install-weka ============================
locals {
  backends_ips  = format("(%s)", join(" ", flatten([
  for i in range(var.cluster_size) : [
  for j in range(length(google_compute_network.vpc_network)) : [
    google_compute_instance.compute[i].network_interface[j].network_ip
  ]
  ]
  ])))
  gws_addresses = format("(%s)", join(" ", [for i in range(var.nics_number) : google_compute_subnetwork.subnetwork[i].gateway_address]))
}

resource "null_resource" "install_weka" {
  connection {
    host        = google_compute_instance.compute[0].network_interface[0].access_config[0].nat_ip
    type        = "ssh"
    user        = var.username
    timeout     = "500s"
    private_key = file(var.private_key_filename)
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 600",
      "echo '#!/bin/bash' > /tmp/install_weka.sh", "echo 'IPS=${local.backends_ips}' >> /tmp/install_weka.sh",
      "echo 'HOSTS_NUM=${var.cluster_size}' >> /tmp/install_weka.sh",
      "echo 'NICS_NUM=${var.nics_number}' >> /tmp/install_weka.sh",
      "echo 'GWS=${local.gws_addresses}' >> /tmp/install_weka.sh",
      "echo 'CLUSTER_NAME=${var.cluster_name}' >> /tmp/install_weka.sh",
      "echo 'NVMES_NUM=${var.nvmes_number}' >> /tmp/install_weka.sh", "cat /tmp/script.sh >> /tmp/install_weka.sh",
      "chmod +x /tmp/install_weka.sh", "/tmp/install_weka.sh",
    ]
  }

  depends_on = [google_compute_instance.compute, google_compute_network_peering.peering, google_compute_firewall.sg_private]
}
