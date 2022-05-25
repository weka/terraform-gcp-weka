resource "google_compute_network" "vpc_network" {
  count                   = 5
  project                 = "wekaio-rnd"
  name                    = "vpc-test-${count.index}"
  auto_create_subnetworks = false
  mtu                     = 1460
}


resource "google_compute_subnetwork" "public-subnetwork" {
  project       = "wekaio-rnd"
  count         = length(google_compute_network.vpc_network)
  name          = "subnet-test-${count.index}"
  ip_cidr_range = "10.${count.index}.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network[count.index].name
}

resource "google_compute_network_peering" "peering-0" {
  for_each     = toset(["1", "2", "3", "4"])
  name         = "peering-0-${each.key}"
  network      = google_compute_network.vpc_network[0].self_link
  peer_network = google_compute_network.vpc_network[tonumber(each.key)].self_link
}

resource "google_compute_network_peering" "peering-1" {
  for_each     = toset(["0", "2", "3", "4"])
  name         = "peering-1-${each.key}"
  network      = google_compute_network.vpc_network[1].self_link
  peer_network = google_compute_network.vpc_network[tonumber(each.key)].self_link
}

resource "google_compute_network_peering" "peering-2" {
  for_each     = toset(["0", "1", "3", "4"])
  name         = "peering-2-${each.key}"
  network      = google_compute_network.vpc_network[2].self_link
  peer_network = google_compute_network.vpc_network[tonumber(each.key)].self_link
}

resource "google_compute_network_peering" "peering-3" {
  for_each     = toset(["0", "1", "2", "4"])
  name         = "peering-3-${each.key}"
  network      = google_compute_network.vpc_network[3].self_link
  peer_network = google_compute_network.vpc_network[tonumber(each.key)].self_link
}
resource "google_compute_network_peering" "peering-4" {
  for_each     = toset(["0", "1", "2", "3"])
  name         = "peering-4-${each.key}"
  network      = google_compute_network.vpc_network[4].self_link
  peer_network = google_compute_network.vpc_network[tonumber(each.key)].self_link
}

resource "google_compute_instance" "compute" {
  project      = "wekaio-rnd"
  count        = length(google_compute_network.vpc_network)
  name         = "test-${count.index}"
  machine_type = "c2-standard-8"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
    }
  }

  network_interface {
    subnetwork_project = "wekaio-rnd"
    subnetwork         = google_compute_subnetwork.public-subnetwork[0].name
    access_config {}
  }
  network_interface {
    subnetwork_project = "wekaio-rnd"
    subnetwork         = google_compute_subnetwork.public-subnetwork[1].name
    access_config {}
  }
  network_interface {
    subnetwork_project = "wekaio-rnd"
    subnetwork         = google_compute_subnetwork.public-subnetwork[2].name
    access_config {}
  }
  network_interface {
    subnetwork_project = "wekaio-rnd"
    subnetwork         = google_compute_subnetwork.public-subnetwork[3].name
    access_config {}
  }
  network_interface {
    subnetwork_project = "wekaio-rnd"
    subnetwork         = google_compute_subnetwork.public-subnetwork[4].name
    access_config {}
  }

}
