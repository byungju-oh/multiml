############################
# variables
############################
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "vnet_name"           { type = string }
variable "subnet_name"         { type = string }
variable "environment"         { type = string }
variable "project_name"        { type = string }

# 클러스터 설정
variable "node_count"   { 
    type = number
    default = 2 
    }

variable "vm_size"      { 
    type = string
    default = "Standard_B2s" 
    }

variable "disk_size_gb" { 
    type = number
    default = 50 
    }

# (옵션) 로그 보존일
variable "log_analytics_retention_days" {
  type    = number
  default = 30
}

############################
# data sources
############################
data "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "main" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

############################
# Log Analytics (for AKS monitoring)
############################
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-${var.environment}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
}

############################
# AKS
############################
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project_name}-${var.environment}"

  # Kubernetes 버전 (필요 시 최신으로 조정 가능)
  kubernetes_version = "1.33.2"

  default_node_pool {
    name            = "default"
    # node_count      = var.node_count
    vm_size         = var.vm_size
    os_disk_size_gb = var.disk_size_gb
    vnet_subnet_id  = data.azurerm_subnet.main.id

    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5

    node_labels = {
      environment = var.environment
      project     = var.project_name
    }

    # node_taints = ["workload-type=ml:NoSchedule"]
  }

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  # 네트워크 프로필
  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    dns_service_ip     = "10.2.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
    #service_cidr       = "10.1.0.0/24"
    service_cidr       = "10.2.0.0/16"
  }

  # RBAC
  role_based_access_control_enabled = true

  # ---- Add-ons (최신 문법) ----
  # 모니터링(OMS/Container Insights)
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # HTTP Application Routing (dev/test용 간편 Ingress)
#   http_application_routing_enabled = true

  # 태그
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

############################
# outputs
############################
output "cluster_name"      { value = azurerm_kubernetes_cluster.main.name }
output "cluster_fqdn"      { value = azurerm_kubernetes_cluster.main.fqdn }
output "kubeconfig_command" {
  value = "az aks get-credentials --resource-group ${var.resource_group_name} --name ${azurerm_kubernetes_cluster.main.name}"
}
output "cluster_identity" {
  value = azurerm_kubernetes_cluster.main.identity[0].principal_id
}
output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}
