resource "google_compute_network" "vpc_network" {
  count                   = var.nics_number
  name                    = "${var.prefix}-vpc-${count.index}"
  auto_create_subnetworks = false
  mtu                     = 1460
}

# ======================= subnet ==========================
locals {
  temp = flatten([
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
  source_tags = ["ssh"]
}

resource "google_compute_firewall" "sg_private" {
  count         = length(google_compute_network.vpc_network)
  name          = "${var.prefix}-ag-all-${count.index}"
  network       = google_compute_network.vpc_network[count.index].name
  source_ranges = ["10.0.0.0/8"]
  allow {
    protocol = "all"
  }
  source_tags = ["all"]
}

# ======================== autoscaler ============================
data "google_compute_image" "centos_7" {
  family  = "centos-7"
  project = "centos-cloud"
}

resource "google_compute_instance_template" "backends-template" {
  name           = "${var.prefix}-backends"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-backends"]
  labels = {
    cluster_name = var.cluster_name
  }

  disk {
    source_image = data.google_compute_image.centos_7.id
    disk_size_gb = 50
    boot         = true
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

  dynamic "disk" {
    for_each = range(var.nvmes_number)
    content {
      interface    = "NVME"
      boot         = false
      type         = "SCRATCH"
      disk_type    = "local-ssd"
      disk_size_gb = 375
    }
  }

  metadata = {
    ssh-keys = "${var.username}:${tls_private_key.ssh.public_key_openssh}"
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

resource "random_password" "password" {
  length           = 16
  lower = true
  upper = true
  numeric = true
  special = false
}

resource "google_compute_instance_template" "join-template" {
  name           = "${var.prefix}-join"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["${var.prefix}-backends"]
  labels = {
    cluster_name = var.cluster_name
  }

  disk {
    source_image = data.google_compute_image.centos_7.id
    disk_size_gb = 50
    boot         = true
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

  dynamic "disk" {
    for_each = range(var.nvmes_number)
    content {
      interface    = "NVME"
      boot         = false
      type         = "SCRATCH"
      disk_type    = "local-ssd"
      disk_size_gb = 375
    }
  }

  metadata = {
    ssh-keys = "${var.username}:${tls_private_key.ssh.public_key_openssh}"
  }

  metadata_startup_script = <<-EOT
    curl -X POST https://${var.region}-${var.project}.cloudfunctions.net/join -H "Content-Type:application/json"  -d '{"project": "${var.project}", "zone": "${var.zone}","username": "${var.weka_username}", "password": "${random_password.password.result}", "tag": "${var.prefix}-backends"}' > /tmp/join.sh
    chmod +x /tmp/join.sh
    /tmp/join.sh
 EOT
}

resource "google_compute_target_pool" "target_pool" {
  name = "${var.prefix}-target-pool"
}

resource "google_compute_instance_group_manager" "igm" {
  name = "${var.prefix}-igm"
  zone = var.zone

  version {
    instance_template = google_compute_instance_template.backends-template.id
    name              = "primary"
  }

  target_pools       = [google_compute_target_pool.target_pool.id]
  base_instance_name = "${var.prefix}-compute"

  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = 0
  }
}

resource "google_compute_autoscaler" "auto-scaler" {
  name   = "${var.prefix}-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.igm.id

  autoscaling_policy {
    max_replicas = 24
    min_replicas = var.cluster_size
  }
}

resource "google_compute_health_check" "autohealing" {
  name                = "autohealing-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds

  http_health_check {
    request_path = "/api/v2/healthcheck/"
    port         = "14000"
  }
}

# ======================== install-weka ============================
resource "null_resource" "wait_for_compute" {
  provisioner "local-exec" {
    command = <<-EOT
      compute=$(gcloud compute instance-groups list-instances weka-igm --zone europe-west1-b 2>&1 | grep RUNNING | wc -l)
      while [ $compute != ${var.cluster_size} ]
      do
        echo "waiting for computes to be up ($compute/${var.cluster_size})..."
        sleep 10s
        compute=$(gcloud compute instance-groups list-instances weka-igm --zone europe-west1-b 2>&1 | grep RUNNING | wc -l)
      done
    EOT
    interpreter = ["bash", "-ce"]
  }
  depends_on = [google_compute_autoscaler.auto-scaler]
}

data "google_compute_instance_group" "node_instance_groups" {
  self_link = google_compute_instance_group_manager.igm.instance_group
  depends_on = [google_compute_autoscaler.auto-scaler, null_resource.wait_for_compute]
}

data "google_compute_instance" "compute" {
  count     = var.cluster_size
  self_link = tolist(data.google_compute_instance_group.node_instance_groups.instances)[count.index]
  depends_on = [google_compute_autoscaler.auto-scaler, null_resource.wait_for_compute]
}

locals {
  backends_ips = format("(%s)", join(" ", flatten([
  for i in range(var.cluster_size) : [
  for j in range(length(google_compute_network.vpc_network)) : [
    data.google_compute_instance.compute[i].network_interface[j].network_ip
  ]
  ]
  ])))
  gws_addresses = format("(%s)", join(" ", [for i in range(var.nics_number) : google_compute_subnetwork.subnetwork[i].gateway_address]))
}

resource "null_resource" "install_weka" {
  connection {
    host        = data.google_compute_instance.compute[0].network_interface[0].access_config[0].nat_ip
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
      "echo 'NVMES_NUM=${var.nvmes_number}' >> /tmp/install_weka.sh",
      "echo 'ADMIN_USERNAME=${var.weka_username}' >> /tmp/install_weka.sh",
      "echo 'ADMIN_PASSWORD=${random_password.password.result}' >> /tmp/install_weka.sh",
      "cat /tmp/script.sh >> /tmp/install_weka.sh",
      "chmod +x /tmp/install_weka.sh", "/tmp/install_weka.sh",
    ]
  }

  depends_on = [
    data.google_compute_instance.compute, google_compute_network_peering.peering, google_compute_firewall.sg_private
  ]
}

resource "null_resource" "replace-template" {
  provisioner "local-exec" {
    command = <<-EOT
            gcloud compute instance-groups managed set-instance-template ${google_compute_instance_group_manager.igm.name} --template=${google_compute_instance_template.join-template.name} --zone ${var.zone}
    EOT
    interpreter = ["bash", "-ce"]
  }
  depends_on = [null_resource.install_weka, google_cloudfunctions_function.join_function]
}

# ======================== cloud function ============================

resource "null_resource" "generate_cloud_functions_zips" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p cloud-functions-zip

      cd cloud-functions/join
      zip -r join.zip join.go go.mod
      mv join.zip ../../cloud-functions-zip/

      cd ../fetch
      zip -r fetch.zip fetch.go go.mod
      mv fetch.zip ../../cloud-functions-zip/

      cd ../scale
      zip -r scale.zip connectors lib protocol scale.go  go.mod
      mv scale.zip ../../cloud-functions-zip/

    EOT
    interpreter = ["bash", "-ce"]
  }
}

resource "google_storage_bucket" "cloud_functions" {
  name     = "${var.prefix}-cloud-functions"
  location = "EU"
}

# ======================== join ============================
resource "google_storage_bucket_object" "join_zip" {
  name   = "join.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/join.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}


resource "google_cloudfunctions_function" "join_function" {
  name        = "join"
  description = "join new instance"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.join_zip.name
  trigger_http          = true
  entry_point           = "Join"
}


# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "join_invoker" {
  project        = google_cloudfunctions_function.join_function.project
  region         = google_cloudfunctions_function.join_function.region
  cloud_function = google_cloudfunctions_function.join_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}


resource "google_secret_manager_secret_iam_member" "member-sa-username-secret" {
  project = google_secret_manager_secret.secret_weka_username.project
  secret_id = google_secret_manager_secret.secret_weka_username.id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${var.project}@appspot.gserviceaccount.com"
}


resource "google_secret_manager_secret_iam_member" "member-sa-password-secret" {
  project = google_secret_manager_secret.secret_weka_password.project
  secret_id = google_secret_manager_secret.secret_weka_password.id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${var.project}@appspot.gserviceaccount.com"
}


# ======================== fetch ============================

resource "google_storage_bucket_object" "fetch_zip" {
  name   = "fetch.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/fetch.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "fetch_function" {
  name        = "fetch"
  description = "fetch cluster info"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.fetch_zip.name
  trigger_http          = true
  entry_point           = "Fetch"
  environment_variables = {
    project: var.project
    zone: var.zone
    instance_group: google_compute_instance_group_manager.igm.name
    cluster_name: var.cluster_name
  }
}


# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "fetch_invoker" {
  project        = google_cloudfunctions_function.fetch_function.project
  region         = google_cloudfunctions_function.fetch_function.region
  cloud_function = google_cloudfunctions_function.fetch_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ======================== scale ============================

resource "google_storage_bucket_object" "scale_zip" {
  name   = "scale.zip"
  bucket = google_storage_bucket.cloud_functions.name
  source = "cloud-functions-zip/scale.zip"
  depends_on = [null_resource.generate_cloud_functions_zips]
}

resource "google_cloudfunctions_function" "scale_function" {
  name        = "scale"
  description = "scale cluster"
  runtime     = "go116"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.cloud_functions.name
  source_archive_object = google_storage_bucket_object.scale_zip.name
  trigger_http          = true
  entry_point           = "Scale"
  vpc_connector         = google_vpc_access_connector.connector.name
  ingress_settings      = "ALLOW_ALL"
  vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"


}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "scale_invoker" {
  project        = google_cloudfunctions_function.scale_function.project
  region         = google_cloudfunctions_function.scale_function.region
  cloud_function = google_cloudfunctions_function.scale_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "null_resource" "write_weka_password_to_local_file" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "${random_password.password.result}" > weka_cluster_admin_password
    EOT
    interpreter = ["bash", "-ce"]
  }
}


#================ Vpc connector ==========================
resource "google_project_service" "vpc-access-api" {
  project = var.project
  service = "vpcaccess.googleapis.com"
  disable_on_destroy = false
}


resource "google_vpc_access_connector" "connector" {
  name          = "${var.prefix}-vpc-connector"
  ip_cidr_range = var.connector
  network       = google_compute_network.vpc_network[0].name
}


output "remote-exec-machine" {
  value = data.google_compute_instance.compute[0].network_interface[0].access_config[0].nat_ip
}
