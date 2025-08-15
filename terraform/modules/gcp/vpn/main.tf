# terraform/modules/gcp/vpn/main.tf

variable "project_id" { type = string }
variable "region" { type = string }
variable "vpc_name" { type = string }
variable "vpc_id" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "azure_vnet_cidr" { type = string }
variable "azure_gateway_ip" { 
  type = string 
  description = "Azure Gateway IP address"
}
variable "gcp_vpc_cidr" { 
  type = string 
  description = "GCP VPC CIDR range"
}

# VPN Gateway용 고정 IP
resource "google_compute_address" "vpn_gateway" {
  name   = "${var.project_name}-${var.environment}-vpn-ip"
  region = var.region
}

# VPN Gateway
resource "google_compute_vpn_gateway" "main" {
  name    = "${var.project_name}-${var.environment}-vpn-gateway"
  network = var.vpc_id
  region  = var.region
}

# 방화벽 규칙 - Azure VNet 트래픽 허용
resource "google_compute_firewall" "allow_azure" {
  name    = "${var.project_name}-${var.environment}-allow-azure"
  network = var.vpc_name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.azure_vnet_cidr]
  target_tags   = ["vpn-tunnel"]
}

# ESP (Encapsulating Security Protocol) 방화벽 규칙
resource "google_compute_firewall" "allow_vpn_esp" {
  name    = "${var.project_name}-${var.environment}-allow-vpn-esp"
  network = var.vpc_name

  allow {
    protocol = "esp"
  }

  source_ranges = ["0.0.0.0/0"]
}

# UDP 500, 4500 (VPN 연결용)
resource "google_compute_firewall" "allow_vpn_udp" {
  name    = "${var.project_name}-${var.environment}-allow-vpn-udp"
  network = var.vpc_name

  allow {
    protocol = "udp"
    ports    = ["500", "4500"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# VPN 터널 (Azure Gateway IP가 준비되면 자동 생성)
resource "google_compute_vpn_tunnel" "azure_tunnel" {
  name          = "${var.project_name}-${var.environment}-to-azure"
  peer_ip       = var.azure_gateway_ip
  shared_secret = "YourSecureSharedKey123!"

  target_vpn_gateway = google_compute_vpn_gateway.main.id

  # 트래픽 셀렉터
  local_traffic_selector  = [var.gcp_vpc_cidr]
  remote_traffic_selector = [var.azure_vnet_cidr]

  depends_on = [
    google_compute_forwarding_rule.esp,
    google_compute_forwarding_rule.udp500,
    google_compute_forwarding_rule.udp4500,
  ]

  # Azure Gateway가 준비될 때까지 기다림
  lifecycle {
    create_before_destroy = true
  }
}

# 포워딩 규칙들
resource "google_compute_forwarding_rule" "esp" {
  name        = "${var.project_name}-${var.environment}-vpn-esp"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_gateway.address
  target      = google_compute_vpn_gateway.main.id
}

resource "google_compute_forwarding_rule" "udp500" {
  name        = "${var.project_name}-${var.environment}-vpn-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_address.vpn_gateway.address
  target      = google_compute_vpn_gateway.main.id
}

resource "google_compute_forwarding_rule" "udp4500" {
  name        = "${var.project_name}-${var.environment}-vpn-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_address.vpn_gateway.address
  target      = google_compute_vpn_gateway.main.id
}

# Azure VNet으로의 라우팅
resource "google_compute_route" "azure_route" {
  name       = "${var.project_name}-${var.environment}-to-azure-route"
  network    = var.vpc_name
  dest_range = var.azure_vnet_cidr
  priority   = 1000

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.azure_tunnel.id
}

# 출력
output "gateway_ip" {
  value = google_compute_address.vpn_gateway.address
}

output "vpn_gateway_name" {
  value = google_compute_vpn_gateway.main.name
}

output "vpn_gateway_id" {
  value = google_compute_vpn_gateway.main.id
}

output "tunnel_name" {
  value = google_compute_vpn_tunnel.azure_tunnel.name
}