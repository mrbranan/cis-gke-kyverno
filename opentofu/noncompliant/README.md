# CIS Noncompliant GKE Automation (Noncompliant Cluster)

**This stack provisions an intentionally noncompliant GKE cluster to serve as a negative test case for plan-level Kyverno JSON policy validation.**

- Automated validation is performed using `scripts/test-opentofu-policies.sh`.
- See `policies/README.md` for policy organization and structure.

## Prerequisites

- [Kyverno CLI must be installed](https://kyverno.io/docs/installation/) locally and/or in your Kubernetes cluster.

## Noncompliant Aspects
This stack is configured to violate key CIS GKE controls, including:

- GKE master endpoint is publicly reachable (`private_cluster_config.enable_private_endpoint = false`).
- Node pool runs with private nodes disabled and uses the Compute Engine default service account.
- No audit logging components enabled on the cluster (`logging_config.enable_components = []`).
- No application-layer secrets encryption (`database_encryption` block omitted).
- Network policy disabled and no `kubernetes_network_policy` resource.
- Legacy ABAC enabled (`enable_legacy_abac = true`).
- Shielded GKE Nodes disabled; `image_type = UBUNTU` (not the hardened containerd variant); `workload_metadata_config` omitted so the GKE Metadata Server is bypassable.
- Permissive firewall rule allowing SSH from `0.0.0.0/0`.
- Wildcard IAM role binding (`roles/owner`) on the node-pool SA.
- Secret Manager secret with automatic replication and no CMEK; no `containeranalysis.googleapis.com` API enablement.
- No `google_logging_project_sink` for centralized audit log routing.
- Missing `resource_labels` / labels everywhere.

## Purpose
This stack is used to demonstrate that Kyverno JSON policies can detect and fail noncompliant infrastructure at the OpenTofu plan stage.

---

**This stack should fail all relevant CIS GKE policies when scanned at plan time.**
