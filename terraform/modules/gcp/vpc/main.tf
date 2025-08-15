variable "project_id" { type = string }
variable "region" { type = string }
variable "vpc_cidr" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }

# VPC 생성
resource "google_compute_network" "main" {
  name                    = "${var.project_name}-${var.environment}-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
}

# 서브넷 생성
resource "google_compute_subnetwork" "main" {
  name          = "${var.project_name}-${var.environment}-subnet"
  ip_cidr_range = var.vpc_cidr
  region        = var.region
  network       = google_compute_network.main.id

  secondary_ip_range {
    range_name    = "k8s-pod-range"
    ip_cidr_range = "10.48.0.0/14"
  }

  secondary_ip_range {
    range_name    = "k8s-service-range" 
    ip_cidr_range = "10.52.0.0/20"
  }
}

# 방화벽 규칙
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.project_name}-${var.environment}-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc_cidr, "10.48.0.0/14", "10.52.0.0/20"]
}

# 출력
output "vpc_name" { value = google_compute_network.main.name }
output "subnet_name" { value = google_compute_subnetwork.main.name }
output "vpc_id" { value = google_compute_network.main.id }