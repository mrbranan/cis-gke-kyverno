variable "project_id" {
  description = "Google Cloud project ID to deploy resources in"
  type        = string
  default     = "cis-gke-noncompliant"
}

variable "region" {
  description = "GCP region to deploy resources in"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "cis-gke-noncompliant"
}

variable "cluster_version" {
  description = "Kubernetes version channel for the GKE cluster"
  type        = string
  default     = "1.29"
}

variable "node_machine_type" {
  description = "Machine type for the GKE node pool"
  type        = string
  default     = "e2-medium"
}
