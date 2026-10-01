terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "learningproject-510004"
  region  = "us-central1"
  zone    = "us-central1-a"
}

# -------------------------
# VPC
# -------------------------
resource "google_compute_network" "web_vpc" {
  name                    = "tf-web-vpc"
  auto_create_subnetworks = false
}

# -------------------------
# Subnet
# -------------------------
resource "google_compute_subnetwork" "web_subnet" {
  name          = "tf-web-subnet"
  ip_cidr_range = "10.20.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.web_vpc.id
}






resource "google_compute_instance" "web_server" {
  name         = "tf-web-server"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network    = google_compute_network.web_vpc.id
    subnetwork = google_compute_subnetwork.web_subnet.id

    access_config {}
  }

  tags = ["tf-web-server"]
}





# -------------------------
# VM
# -------------------------
resource "google_compute_instance" "web_servers" {
  count        = 2
  name         = "tf-web-server-${count.index + 2}"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network    = google_compute_network.web_vpc.id
    subnetwork = google_compute_subnetwork.web_subnet.id

    # Request an ephemeral external/public IP
    access_config {}
  }

  tags = ["tf-web-server"]
}

# -------------------------
# Firewall - SSH
# -------------------------
resource "google_compute_firewall" "allow_ssh" {
  name    = "tf-web-allow-ssh"
  network = google_compute_network.web_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["tf-web-server"]
}

# -------------------------
# Firewall - HTTP
# -------------------------
resource "google_compute_firewall" "allow_http" {
  name    = "tf-web-allow-http"
  network = google_compute_network.web_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["tf-web-server"]
}

# -------------------------
# Output VM Public IP
# -------------------------
output "web_server_public_ips" {
  value = concat(
    [google_compute_instance.web_server.network_interface[0].access_config[0].nat_ip],
    google_compute_instance.web_servers[*].network_interface[0].access_config[0].nat_ip
  )
}
