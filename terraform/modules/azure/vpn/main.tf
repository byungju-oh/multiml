# terraform/modules/azure/vpn/main.tf

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vnet_id" { type = string }
variable "vnet_name" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "gcp_vpc_cidr" { type = string }
variable "gcp_gateway_ip" { type = string }

# Gateway 서브넷 (완전히 다른 범위 사용)
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"  # 이름이 정확히 "GatewaySubnet"이어야 함
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = ["10.1.255.0/27"]  # VNet 끝 범위 사용
}

# VPN Gateway용 Public IP
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "${var.project_name}-${var.environment}-vpn-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "main" {
  name                = "${var.project_name}-${var.environment}-vpn-gateway"
  location            = var.location
  resource_group_name = var.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw1"  # 기본 SKU

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Local Network Gateway (GCP 연결용)
resource "azurerm_local_network_gateway" "gcp" {
  name                = "${var.project_name}-${var.environment}-gcp-local-gateway"
  location            = var.location
  resource_group_name = var.resource_group_name
  gateway_address     = var.gcp_gateway_ip
  address_space       = [var.gcp_vpc_cidr]

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# VPN Connection
resource "azurerm_virtual_network_gateway_connection" "gcp" {
  name                = "${var.project_name}-${var.environment}-azure-to-gcp"
  location            = var.location
  resource_group_name = var.resource_group_name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.gcp.id

  shared_key = "YourSecureSharedKey123!"  # 실제 환경에서는 변수로 관리

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# 출력
output "gateway_ip" {
  value = azurerm_public_ip.vpn_gateway.ip_address
}

output "vpn_gateway_id" {
  value = azurerm_virtual_network_gateway.main.id
}

output "connection_name" {
  value = azurerm_virtual_network_gateway_connection.gcp.name
}