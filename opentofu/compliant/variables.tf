variable "project_id" {
  description = "Google Cloud project ID to deploy resources in"
  type        = string
  default     = "cis-gke-compliant"
}

variable "region" {
  description = "GCP region to deploy resources in"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "cis-gke-compliant"
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

variable "desired_capacity" {
  description = "Initial node count"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum node pool size"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum node pool size"
  type        = number
  default     = 5
}

variable "vpc_cidr" {
  description = "Primary CIDR for the cluster subnetwork"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR for Pod IPs (VPC-native)"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "Secondary CIDR for Service IPs (VPC-native)"
  type        = string
  default     = "10.0.32.0/20"
}

variable "create_network_policy" {
  description = "Whether to create the in-cluster default-deny NetworkPolicy. Disable when running tofu plan without a reachable cluster."
  type        = bool
  default     = false
}
