terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.84"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.71"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# 1단계: GCP VPC
module "gcp_vpc" {
  source = "../../modules/gcp/vpc"
  
  project_id    = var.project_id
  region        = var.gcp_region
  vpc_cidr      = var.gcp_vpc_cidr
  environment   = var.environment
  project_name  = var.project_name
}

# 1단계: Azure VNet
module "azure_vnet" {
  source = "../../modules/azure/vnet"
  
  location      = var.azure_location
  vnet_cidr     = var.azure_vnet_cidr
  environment   = var.environment
  project_name  = var.project_name
  subnet_cidr   = var.azure_subnet_cidr
}


# 기존 내용 유지하고 아래 내용 추가

# 2단계: Azure VPN 먼저 완전히 생성
module "azure_vpn" {
  source = "../../modules/azure/vpn"
  
  resource_group_name = module.azure_vnet.resource_group_name
  location           = var.azure_location
  vnet_id            = module.azure_vnet.vnet_id
  vnet_name          = module.azure_vnet.vnet_name
  environment        = var.environment
  project_name       = var.project_name
  gcp_vpc_cidr       = var.gcp_vpc_cidr
  gcp_gateway_ip     = "1.1.1.1"  # 임시값, 나중에 업데이트됨
  
  depends_on = [module.azure_vnet]
}

# 2단계: GCP VPN (Azure 완료 후 자동 생성)
module "gcp_vpn" {
  source = "../../modules/gcp/vpn"
  
  project_id        = var.project_id
  region            = var.gcp_region
  vpc_name          = module.gcp_vpc.vpc_name
  vpc_id            = module.gcp_vpc.vpc_id
  environment       = var.environment
  project_name      = var.project_name
  azure_vnet_cidr   = var.azure_vnet_cidr
  gcp_vpc_cidr      = var.gcp_vpc_cidr
  azure_gateway_ip  = module.azure_vpn.gateway_ip  # Azure 완료되면 자동으로 받음
  
  # 중요: Azure VPN이 완전히 완료된 후에만 실행
  depends_on = [module.gcp_vpc, module.azure_vpn]
}

# 2단계: Azure 연결 업데이트 (GCP IP 받아서)
resource "null_resource" "update_azure_connection" {
  # GCP VPN이 완료된 후 실행
  depends_on = [module.gcp_vpn]

  # Azure Local Gateway의 GCP IP 업데이트
  provisioner "local-exec" {
    # 역슬래시를 제거하고 한 줄로 합쳤습니다.
    command = "az network local-gateway update --name ${var.project_name}-${var.environment}-gcp-local-gateway --resource-group ${var.project_name}-${var.environment}-rg --gateway-ip-address ${module.gcp_vpn.gateway_ip}"
  }

  # 변경 감지
  triggers = {
    gcp_gateway_ip = module.gcp_vpn.gateway_ip
  }
}