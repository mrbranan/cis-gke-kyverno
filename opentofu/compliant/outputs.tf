output "project_id" {
  description = "Google Cloud project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.main.name
}

output "cluster_endpoint" {
  description = "Private endpoint of the GKE control plane"
  value       = google_container_cluster.main.endpoint
  sensitive   = true
}

output "node_service_account_email" {
  description = "Dedicated node-pool service account"
  value       = google_service_account.gke_nodes.email
}

output "workload_identity_pool" {
  description = "Workload Identity pool for KSA → GSA impersonation"
  value       = google_container_cluster.main.workload_identity_config[0].workload_pool
}

output "kms_key_id" {
  description = "Cloud KMS key used for application-layer secrets encryption"
  value       = google_kms_crypto_key.gke_secrets.id
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.app.id
}
