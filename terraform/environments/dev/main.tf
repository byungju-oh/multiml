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
}