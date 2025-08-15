variable "project_id" { type = string }
variable "region" { type = string }
variable "zone" { type = string }
variable "vpc_name" { type = string }
variable "subnet_name" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }

# 클러스터 설정
variable "node_count" { 
  type = number 
  default = 2
}
variable "machine_type" { 
  type = string 
  default = "e2-standard-2"
}
variable "disk_size_gb" { 
  type = number 
  default = 50
}
variable "preemptible" { 
  type = bool 
  default = true
}

# 서비스 계정
resource "google_service_account" "gke_sa" {
  account_id   = "${var.project_name}-${var.environment}-gke-sa"
  display_name = "GKE Service Account"
}

# IAM 바인딩
resource "google_project_iam_member" "gke_sa_bindings" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/storage.objectViewer"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# GKE 클러스터
resource "google_container_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-gke"
  location = var.zone
  
  # VPC 설정
  network    = var.vpc_name
  subnetwork = var.subnet_name
  
  # IP 할당 정책
  ip_allocation_policy {
    cluster_secondary_range_name  = "k8s-pod-range"
    services_secondary_range_name = "k8s-service-range"
  }
  
  # 기본 노드풀 제거 (별도 생성)
  remove_default_node_pool = true
  initial_node_count       = 1
  
  # 네트워크 정책 활성화
  network_policy {
    enabled = true
  }
  
  # 워크로드 아이덴티티
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  # 마스터 인증 네트워크
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks"
    }
  }
  
  # 로깅 및 모니터링
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
  
  # 유지보수 정책
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }
}

# 노드풀
resource "google_container_node_pool" "main" {

  depends_on = [google_container_cluster.main]  
  name       = "${var.project_name}-${var.environment}-nodepool"
  location   = var.zone
  cluster    = google_container_cluster.main.name
#   node_count = var.node_count   이거는 오토스케일링 할꺼면 못씀 이거 는 고정 노드수라
#   initial_node_count = var.node_count # 노드 풀 생성 시 초기 노드 수

  node_config {
    preemptible  = var.preemptible
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"
    
    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    # 워크로드 아이덴티티
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    
    # 레이블
    labels = {
      environment = var.environment
      project     = var.project_name
    }
    
    # Taints (선택사항)
    taint {
      key    = "workload-type"
      value  = "ml"
      effect = "NO_SCHEDULE"
    }
  }
  
  # 자동 업그레이드
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  
  # 자동 스케일링
  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }
}

# 출력
output "cluster_name" { value = google_container_cluster.main.name }
output "cluster_endpoint" { value = google_container_cluster.main.endpoint }
output "cluster_ca_certificate" { 
  value = google_container_cluster.main.master_auth.0.cluster_ca_certificate 
}
output "kubeconfig_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --zone ${var.zone} --project ${var.project_id}"
}