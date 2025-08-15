variable "location" { type = string }
variable "vnet_cidr" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "subnet_cidr" { type = string }
variable "aks_subnet_cidr" { type = string }

# 리소스 그룹
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# VNet 생성
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-${var.environment}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# 메인 서브넷 (일반 리소스용)
resource "azurerm_subnet" "main" {
  name                 = "${var.project_name}-${var.environment}-main-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

# AKS 전용 서브넷
resource "azurerm_subnet" "aks" {
  name                 = "${var.project_name}-${var.environment}-aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# NSG (Network Security Group) - 메인용
resource "azurerm_network_security_group" "main" {
  name                = "${var.project_name}-${var.environment}-main-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowInternal"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "AllowGCP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}

# NSG (AKS 전용)
resource "azurerm_network_security_group" "aks" {
  name                = "${var.project_name}-${var.environment}-aks-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Kubernetes API Server
  security_rule {
    name                       = "AllowKubernetesAPI"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # 노드 간 통신
  security_rule {
    name                       = "AllowNodeCommunication"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.aks_subnet_cidr
    destination_address_prefix = var.aks_subnet_cidr
  }
  
  # GCP에서 오는 트래픽
  security_rule {
    name                       = "AllowGCP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}

# NSG 연결
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# 출력
output "resource_group_name" { value = azurerm_resource_group.main.name }
output "vnet_name" { value = azurerm_virtual_network.main.name }
output "subnet_name" { value = azurerm_subnet.main.name }
output "aks_subnet_name" { value = azurerm_subnet.aks.name }
output "vnet_id" { value = azurerm_virtual_network.main.id }