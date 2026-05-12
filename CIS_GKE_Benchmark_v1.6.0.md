# 📘 CIS Google Kubernetes Engine (GKE) Benchmark Alignment (v1.6.0)

> **Disclaimer:**
> This repository references the *CIS Google Kubernetes Engine Benchmark v1.6.0* for educational and alignment purposes only.
> No CIS Benchmark content is reproduced here.
> For full and official benchmark details, please visit the [CIS SecureSuite website](https://www.cisecurity.org/cis-securesuite) or contact CIS Legal at [legalnotices@cisecurity.org](mailto:legalnotices@cisecurity.org).

*This document summarizes high-level security controls inspired by the CIS GKE Benchmark to help demonstrate compliance automation using Kyverno and other CNCF tools.*

---

## ✅ Section 1 – Control Plane Components
Informational only; no actionable security controls are defined in this section.

---

## 🛠️ Section 2 – Control Plane Configuration

### 🔍 Logging
- **2.1.1** Validate that cluster audit logging is enabled (Cloud Logging system, workload, and API server components).
- **2.1.2** Confirm that audit logs are routed to a centrally managed destination (log sink to Cloud Logging bucket, BigQuery, or Pub/Sub).
- **2.1.3** Ensure audit log retention meets the organization's retention requirement (≥ 90 days on the destination log bucket).

---

## 🧱 Section 3 – Worker Nodes

### 📄 Worker Node Configuration Files
- **3.1.1–3.1.4** Validate secure permissions and ownership for `kubeconfig` and kubelet configuration files on GKE node images (Container-Optimized OS `cos_containerd` and `ubuntu_containerd`) to prevent unauthorized modification or access.

### ⚙️ Kubelet Security
- **3.2.1–3.2.9** Apply secure kubelet settings such as disabling anonymous access, enforcing webhook authorization, enabling certificate rotation, and restricting read-only ports. On GKE these are largely managed by Google; this benchmark verifies the resulting node-local state via the included DaemonSet scanner.

---

## 🔐 Section 4 – Policies

### 🧾 RBAC and Service Accounts
- **4.1.x** Apply the principle of least privilege by limiting cluster-admin roles, controlling secret access, and restricting wildcard permissions.
- Avoid using default service accounts in production namespaces; bind Kubernetes ServiceAccounts to dedicated Google Service Accounts via Workload Identity.

### 🛡️ Pod Security Standards
- **4.2.x** Prevent the admission of privileged or host-namespace containers and enforce least-privilege runtime configurations.

### 🌐 Network Policies and CNI
- **4.3.x** Use a CNI that supports Kubernetes NetworkPolicies (GKE network policy with Calico, or GKE Dataplane V2) and ensure every namespace defines network restrictions.

### 🔑 Secrets Management
- **4.4.x** Prefer file-based secrets over environment variables and consider integrating with external secret managers such as Google Secret Manager or HashiCorp Vault.

### 🧩 Extensible Admission Control
- **4.5.x** Use admission controllers (Kyverno, Gatekeeper) and consider GKE Binary Authorization to enforce supply-chain provenance.

### 📦 General Policies
- **4.6.x** Create administrative boundaries between namespaces and avoid deploying workloads in the default namespace.

---

## 🧩 Section 5 – Managed Services and Integrations

### 🖼️ Image Registry and Scanning
- **5.1.1** Use trusted image registries (Artifact Registry) and enable Container Analysis (vulnerability scanning) at the project level.
- **5.1.2** Minimize cluster access to read-only for Artifact Registry — node-pool service accounts should hold `roles/artifactregistry.reader` only.

### 🔐 Identity and Access Management
- **5.2.x** Use Workload Identity to bind Kubernetes ServiceAccounts to Google Service Accounts; avoid running node pools with the Compute Engine default service account.

### 🗝️ Cloud Key Management Service
- **5.3.x** Encrypt at-rest data with Cloud KMS Customer-Managed Encryption Keys (CMEK); enable key rotation.

### 🌐 Node Metadata
- **5.4.x** Block access to the legacy GCE metadata endpoint by enabling the **GKE Metadata Server** (`workload_metadata_config.mode = GKE_METADATA`).

### 🧱 Node Configuration and Maintenance
- **5.5.x** Use Container-Optimized OS (`COS_CONTAINERD`) node images, enable Shielded GKE Nodes (Secure Boot + Integrity Monitoring), and bound node-pool autoscaling.

### 🌐 Cluster Networking
- **5.6.x** Use VPC-native (alias IP) clusters, restrict the master endpoint to authorized networks, deploy private clusters (private nodes + private endpoint), enable network policy (Calico or Dataplane V2), and create namespace-scoped NetworkPolicies.

### 🛡️ Cluster Security
- **5.7.x** Enable Binary Authorization (`PROJECT_SINGLETON_POLICY_ENFORCE`), consider Confidential GKE Nodes, and keep clusters on a supported release channel.

### 👥 Authentication and Authorization
- **5.8.x** Manage cluster access through Google IAM and Google Groups for GKE; disable legacy ABAC and client-certificate authentication.

### 💾 Storage
- **5.9.x** Encrypt persistent disks with CMEK.

### 🔒 Other Cluster Configurations
- **5.10.1** Enable Application-layer Secrets Encryption (`database_encryption.state = ENCRYPTED` with a Cloud KMS key) so etcd Secrets are encrypted with a customer-managed key.

---

## ⚖️ License & Attribution
This repository is **not affiliated with or endorsed by CIS**.
CIS® and the CIS Benchmarks™ are trademarks of the Center for Internet Security, Inc.
Official benchmarks are available exclusively to CIS members via [CIS SecureSuite](https://www.cisecurity.org/cis-securesuite).
