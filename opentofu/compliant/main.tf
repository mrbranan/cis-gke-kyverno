terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  common_labels = {
    environment = "production"
    owner       = "platform-team"
  }
}

# ----------------------------------------------------------------------------
# Networking — VPC-native (CIS 5.6.2), private firewall posture (CIS 5.6.1)
# ----------------------------------------------------------------------------

resource "google_compute_network" "main" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "private" {
  name                     = "${var.cluster_name}-subnet"
  ip_cidr_range            = var.vpc_cidr
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.cluster_name}-allow-internal"
  network = google_compute_network.main.id
  direction = "INGRESS"

  source_ranges = [var.vpc_cidr, var.pods_cidr]

  allow {
    protocol = "tcp"
    ports    = ["443", "10250", "53"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }
}

# ----------------------------------------------------------------------------
# Cloud KMS — application-layer secrets encryption (CIS 5.10.1, 5.3.x)
# ----------------------------------------------------------------------------

resource "google_kms_key_ring" "gke" {
  name     = "${var.cluster_name}-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "gke_secrets" {
  name            = "${var.cluster_name}-gke-secrets"
  key_ring        = google_kms_key_ring.gke.id
  rotation_period = "7776000s" # 90 days

  labels = local.common_labels

  lifecycle {
    prevent_destroy = false
  }
}

# ----------------------------------------------------------------------------
# Service accounts — dedicated node-pool SA + Workload Identity (CIS 5.2.1, 5.8.1)
# ----------------------------------------------------------------------------

resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Node Pool Service Account (least-privilege)"
}

# Least-privilege role bindings for the node-pool SA — CIS 4.1.4 / 5.1.2
resource "google_project_iam_member" "node_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "node_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "node_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "node_resource_metadata_writer" {
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "node_artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Workload Identity workload SA (impersonated by a KSA in-cluster) — CIS 5.8.1
resource "google_service_account" "workload" {
  account_id   = "${var.cluster_name}-workload"
  display_name = "Application Workload Identity Service Account"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/app]"
}

# ----------------------------------------------------------------------------
# GKE cluster — private, encrypted, audit-logged, Workload-Identity-enabled
# ----------------------------------------------------------------------------

resource "google_container_cluster" "main" {
  provider = google-beta

  name     = var.cluster_name
  location = var.region

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.private.id

  remove_default_node_pool = true
  initial_node_count       = 1

  enable_legacy_abac = false

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.0.0/8"
      display_name = "internal"
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.gke_secrets.id
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS", "API_SERVER"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  release_channel {
    channel = "REGULAR"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  resource_labels = local.common_labels
}

resource "google_container_node_pool" "main" {
  provider = google-beta

  name     = "${var.cluster_name}-pool"
  location = var.region
  cluster  = google_container_cluster.main.name

  autoscaling {
    min_node_count = var.min_size
    max_node_count = var.max_size
  }

  initial_node_count = var.desired_capacity

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    service_account = google_service_account.gke_nodes.email
    image_type      = "COS_CONTAINERD"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = local.common_labels
  }
}

# ----------------------------------------------------------------------------
# Artifact Registry + Container Analysis — CIS 5.1.1
# ----------------------------------------------------------------------------

resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "${var.cluster_name}-app"
  description   = "Container images for the GKE cluster"
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"

  labels = local.common_labels
}

resource "google_project_service" "containeranalysis" {
  project            = var.project_id
  service            = "containeranalysis.googleapis.com"
  disable_on_destroy = false
}

# ----------------------------------------------------------------------------
# Secret Manager — CMEK-replicated secrets (CIS 5.3.2)
# ----------------------------------------------------------------------------

resource "google_secret_manager_secret" "app_secrets" {
  secret_id = "${var.cluster_name}-app-secrets"

  replication {
    user_managed {
      replicas {
        location = var.region
        customer_managed_encryption {
          kms_key_name = google_kms_crypto_key.gke_secrets.id
        }
      }
    }
  }

  labels = local.common_labels
}

# ----------------------------------------------------------------------------
# Cloud Logging — centralized audit log routing with retention (CIS 2.1.2/3)
# ----------------------------------------------------------------------------

resource "google_logging_project_bucket_config" "audit" {
  project        = var.project_id
  location       = "global"
  retention_days = 90
  bucket_id      = "${var.cluster_name}-audit-logs"
}

resource "google_logging_project_sink" "audit" {
  name                   = "${var.cluster_name}-audit-sink"
  destination            = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/${google_logging_project_bucket_config.audit.bucket_id}"
  filter                 = "resource.type=k8s_cluster AND resource.labels.cluster_name=\"${var.cluster_name}\""
  unique_writer_identity = true
}

# ----------------------------------------------------------------------------
# Default-deny NetworkPolicy — CIS 5.6.7
# ----------------------------------------------------------------------------

resource "kubernetes_network_policy" "default_deny_all" {
  count = var.create_network_policy ? 1 : 0

  metadata {
    name      = "default-deny-all"
    namespace = "default"
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}
