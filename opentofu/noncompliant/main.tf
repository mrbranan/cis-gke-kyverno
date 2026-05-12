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

# ----------------------------------------------------------------------------
# Networking — auto-mode VPC + permissive firewall (intentionally broken)
# ----------------------------------------------------------------------------

resource "google_compute_network" "main" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = true
  # No labels (violates require-labels)
}

# Permissive ingress rule — SSH from anywhere (violates CIS 5.6.1)
resource "google_compute_firewall" "open_ssh" {
  name      = "${var.cluster_name}-open-ssh"
  network   = google_compute_network.main.id
  direction = "INGRESS"

  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ----------------------------------------------------------------------------
# IAM — wildcard ownership granted to the workload SA (violates CIS 4.1.1/4.1.3/4.1.8)
# ----------------------------------------------------------------------------

# Custom role with a wildcard permission — violates CIS 4.1.3
resource "google_project_iam_custom_role" "wildcard" {
  role_id     = "${replace(var.cluster_name, "-", "_")}_wildcard"
  title       = "Wildcard role"
  description = "Intentionally wildcard permissions for negative testing"
  permissions = ["*"]
}

resource "google_service_account" "overprivileged" {
  account_id   = "${var.cluster_name}-overpriv"
  display_name = "Overprivileged Workload SA (negative test)"
}

# Overly broad role binding — violates CIS 4.1.1 / 4.1.4
resource "google_project_iam_member" "owner_on_workload" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.overprivileged.email}"
}

# Token-creator on a broad principal — violates CIS 4.1.8
resource "google_service_account_iam_member" "broad_token_creator" {
  service_account_id = google_service_account.overprivileged.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "allAuthenticatedUsers"
}

# ----------------------------------------------------------------------------
# GKE cluster — public endpoint, no audit logging, no encryption, legacy ABAC
# ----------------------------------------------------------------------------

resource "google_container_cluster" "main" {
  provider = google-beta

  name     = var.cluster_name
  location = var.region

  network = google_compute_network.main.id

  remove_default_node_pool = false
  initial_node_count       = 1

  enable_legacy_abac = true # Violates CIS 2.2.1 / 5.8.x

  private_cluster_config {
    enable_private_nodes    = false # Violates CIS 5.6.5
    enable_private_endpoint = false # Violates CIS 5.6.4
  }

  # No master_authorized_networks_config — public endpoint reachable from anywhere
  # No workload_identity_config — violates CIS 5.2.1 / 5.8.1
  # No database_encryption — violates CIS 5.10.1
  # logging_config left to defaults / empty so audit logs are not emitted
  logging_config {
    enable_components = []
  }

  network_policy {
    enabled = false # Violates CIS 4.3.1 / 5.6.7
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = true # Legacy client-cert auth — violates CIS 5.8.x
    }
  }

  # No resource_labels (violates require-labels)
}

resource "google_container_node_pool" "main" {
  provider = google-beta

  name     = "${var.cluster_name}-pool"
  location = var.region
  cluster  = google_container_cluster.main.name

  autoscaling {
    min_node_count = 1
    max_node_count = 500 # Unbounded autoscaling — violates CIS 5.5.2
  }

  initial_node_count = 1

  node_config {
    machine_type = var.node_machine_type
    image_type   = "UBUNTU" # Not the hardened *_CONTAINERD variant — violates CIS 5.5.1

    # service_account omitted — falls back to the Compute Engine default SA (violates CIS 5.2.1 / 4.1.4)
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    shielded_instance_config {
      enable_secure_boot          = false # Violates CIS 5.5.2
      enable_integrity_monitoring = false # Violates CIS 5.5.2
    }

    # No workload_metadata_config — GCE metadata server is exposed (violates CIS 5.4.1)
    # No labels (violates require-labels)
  }
}

# ----------------------------------------------------------------------------
# Artifact Registry — no Container Analysis API enablement (violates CIS 5.1.1)
# ----------------------------------------------------------------------------

resource "google_artifact_registry_repository" "insecure_app" {
  location      = var.region
  repository_id = "${var.cluster_name}-insecure-app"
  description   = "Insecure container repository for negative testing"
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"
  # No labels (violates require-labels)
  # No corresponding google_project_service "containeranalysis.googleapis.com" (violates CIS 5.1.1)
}

# ----------------------------------------------------------------------------
# Secret Manager — automatic replication, no CMEK (violates CIS 5.3.2)
# ----------------------------------------------------------------------------

resource "google_secret_manager_secret" "insecure_secrets" {
  secret_id = "${var.cluster_name}-insecure-secrets"

  replication {
    auto {}
  }
  # No labels (violates require-labels)
}

# Missing resources that compliance policies expect:
# - No google_kms_crypto_key (violates CIS 5.10.1, 5.3.x)
# - No google_logging_project_sink (violates CIS 2.1.2)
# - No google_logging_project_bucket_config (violates CIS 2.1.3)
# - No kubernetes_network_policy (violates CIS 5.6.7)
