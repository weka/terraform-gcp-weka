data "google_compute_image" "weka_image" {
  name  = var.weka_image_name
  project = var.weka_image_project
}

data "google_compute_subnetwork" "subnet" {
  project = var.project
  region         = var.region
  name   = var.subnet_name
}

resource "google_compute_firewall" "allow-ssh" {
  name    = "allow-ssh"
  project = var.project
  network = var.vpc_name
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ======================== instance ============================
resource "google_compute_instance" "compute" {
  project = var.project
  name         = "weka-image"
  machine_type = var.machine_type
  zone         = var.zone
  service_account {
    email = var.sa_email
    scopes = ["cloud-platform"]
  }
  boot_disk {
    initialize_params {
      image = data.google_compute_image.weka_image.id
      size  = 50
    }
  }

  # nic with public ip
  network_interface {
    subnetwork_project = var.project
    subnetwork = var.subnet_name
    access_config {}
  }

  metadata_startup_script = <<-EOT
  set -ex
  yum update -y
  yum install -y \
  elfutils-libelf-devel \
  gcc \
  glibc-headers \
  glibc-devel \
  make \
  perl \
  rpcbind \
  xfsprogs \
  kernel-devel
  gcloud compute instances stop weka-image --zone ${var.zone}
 EOT
}

resource "null_resource" "instance_stopped" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      status=$(gcloud compute instances describe ${google_compute_instance.compute.name} --zone ${var.zone} | grep status | awk '{print $2}')
      while [ $status != "TERMINATED" ]; do
        echo "waiting for instance to become stopped"
        sleep 5
        status=$(gcloud compute instances describe ${google_compute_instance.compute.name} --zone ${var.zone} | grep status | awk '{print $2}')
      done
    EOT
    interpreter = ["bash", "-ce"]
  }
  depends_on = [google_compute_instance.compute]
}


resource "null_resource" "terminate_instance" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      gcloud compute instances delete ${google_compute_instance.compute.name} --zone ${var.zone} --quiet
    EOT
    interpreter = ["bash", "-ce"]
  }
  depends_on = [google_compute_image.weka-image]
}

# ======================== image ============================
resource "google_compute_image" "weka-image" {
  project = var.project
  name = "weka-centos-7"

  source_disk = google_compute_instance.compute.boot_disk[0].source
  depends_on = [null_resource.instance_stopped]
}
