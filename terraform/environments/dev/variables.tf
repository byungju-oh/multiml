variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure 구독 ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP 리전"
  type        = string
  default     = "asia-northeast3"
}

variable "gcp_zone" {
  description = "GCP 존"
  type        = string
  default     = "asia-northeast3-a"
}

variable "azure_location" {
  description = "Azure 리전"
  type        = string
  default     = "Korea Central"
}

variable "gcp_vpc_cidr" {
  description = "GCP VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azure_vnet_cidr" {
  description = "Azure VNet CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "environment" {
  description = "환경명"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "프로젝트명"
  type        = string
  default     = "multicloud-ml"
}