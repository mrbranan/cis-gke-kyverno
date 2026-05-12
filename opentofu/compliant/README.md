# CIS-Compliant GKE Automation (Compliant Cluster)

**This stack provisions a reference CIS-compliant GKE cluster for validating plan-level Kyverno JSON policies. It is used as the gold standard for passing all enforceable CIS controls at the OpenTofu plan stage.**

- Automated validation is performed using `scripts/test-opentofu-policies.sh`.
- See `policies/README.md` for policy organization and structure.

## Prerequisites

- [Kyverno CLI must be installed](https://kyverno.io/docs/installation/) locally and/or in your Kubernetes cluster.
- For real-GCP runs: `gcloud` CLI authenticated against the target project with `container.googleapis.com`, `cloudkms.googleapis.com`, `secretmanager.googleapis.com`, `artifactregistry.googleapis.com`, `containeranalysis.googleapis.com`, and `logging.googleapis.com` enabled.

---

## Overview
This module provisions a CIS-compliant GKE Standard cluster with private nodes and a private endpoint, a Cloud KMS key for application-layer secrets encryption, an Artifact Registry repository with Container Analysis (vulnerability scanning) enabled, a Cloud Logging sink with a long-retention log bucket, and a dedicated node-pool service account bound to least-privilege roles. All provisioning is designed to support a fully private cluster (no public master endpoint).

## Workflow

1. **Provision Infrastructure**
   - Run `tofu apply` from your local workstation or CI/CD to create the VPC, GKE cluster, Cloud KMS key, Artifact Registry repository, Secret Manager secret, and log sink.

2. **Connect to the Cluster (via IAP)**
   - Because the master endpoint is private, connect through Identity-Aware Proxy (IAP) TCP forwarding or a bastion in the same VPC:
     ```sh
     gcloud container clusters get-credentials cis-gke-compliant \
       --region us-central1 \
       --project <project-id>
     ```
   - For TCP-level access from a workstation:
     ```sh
     gcloud compute start-iap-tunnel <bastion-name> 22 \
       --local-host-port=localhost:2222 \
       --zone us-central1-a
     ```

3. **Run OpenTofu and Automation Scripts**
   - Apply Kyverno and CIS policies once you have cluster credentials:
     ```sh
     kubectl apply -f ../../kyverno-node-rbac.yaml
     kubectl apply -f ../../k8s/cis-scanner-pod.yaml   # GKE Standard only
     kubectl apply -R -f ../../policies/kubernetes/
     ```

4. **Cleanup**
   - Run `tofu destroy` for full cleanup of the GCP resources.

## Security & Compliance
- The GKE control plane endpoint is private-only (`private_cluster_config.enable_private_endpoint = true`).
- Node pool uses a dedicated service account (not the Compute Engine default SA) with least-privilege role bindings.
- All actions are auditable via Cloud Audit Logs (Admin Activity and Data Access logs) routed to a long-retention log bucket.

## Outputs
- `cluster_name`: GKE cluster name.
- `cluster_endpoint`: Private endpoint of the cluster master.
- `node_service_account_email`: Dedicated node-pool service account.
- `workload_identity_pool`: `<project>.svc.id.goog` pool for Workload Identity bindings.
- `kms_key_id`: Cloud KMS key used for application-layer secrets encryption.

---

**This approach ensures all provisioning and policy application is done against a private GKE cluster, meeting strict CIS GKE Benchmark v1.6.0 requirements.**
