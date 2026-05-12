# OpenTofu CIS GKE Compliance Testing

This directory contains OpenTofu configurations for testing CIS GKE Benchmark compliance using Kyverno policies at plan-time.

## Overview

The OpenTofu configurations demonstrate compliant vs. non-compliant Google Kubernetes Engine (GKE) infrastructure patterns for CIS security controls validation. These configurations enable automated security compliance testing during the infrastructure planning phase.

## Directory Structure

```
opentofu/
├── README.md                    # This file
├── compliant/                   # CIS-compliant GKE configuration
│   ├── main.tf                 # Main infrastructure resources
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── tofuplan.json          # Generated plan file (JSON)
│   └── tofuplan.binary        # Generated plan file (binary)
└── noncompliant/               # Non-compliant GKE configuration
    ├── main.tf                 # Main infrastructure resources
    ├── variables.tf            # Input variables
    ├── tofuplan.json          # Generated plan file (JSON)
    └── tofuplan.binary        # Generated plan file (binary)
```

## Configuration Profiles

### Compliant Configuration (`compliant/`)

**Purpose**: Demonstrates a CIS GKE Benchmark v1.6.0–compliant infrastructure configuration.

**Security Features**:
- ✅ Private GKE control plane (`enable_private_endpoint = true`, `enable_private_nodes = true`)
- ✅ Comprehensive audit logging (`logging_config.enable_components = ["SYSTEM_COMPONENTS","WORKLOADS","API_SERVER"]`)
- ✅ Application-layer secrets encryption with Cloud KMS (`database_encryption.state = "ENCRYPTED"`)
- ✅ Artifact Registry with Container Analysis (vulnerability scanning) enabled at the project level
- ✅ VPC-native cluster with secondary IP ranges for Pods and Services; private subnetwork
- ✅ Secret Manager secret with CMEK replication
- ✅ Firewall rules restricted to in-VPC source ranges (no `0.0.0.0/0` ingress on SSH/RDP)
- ✅ Resource labels for compliance tracking (`environment`, `owner`)
- ✅ Network policy enabled (Calico) or Dataplane V2
- ✅ Shielded GKE Nodes (Secure Boot + Integrity Monitoring) and GKE Metadata Server enforced
- ✅ Workload Identity bound to a dedicated Google Service Account
- ✅ Binary Authorization in enforce mode

**CIS Controls Implemented**:
- **2.1.1–2.1.3**: Audit logging configuration, destinations, and retention
- **4.3.1 / 5.6.7**: Network policy support
- **5.1.1**: Artifact Registry image scanning
- **5.10.1**: Application-layer secrets encryption (Cloud KMS CMEK)
- **5.2.1 / 5.8.1**: Workload Identity
- **5.5.1 / 5.5.2**: Hardened node image and Shielded GKE Nodes
- **5.6.1–5.6.5**: Firewall rules, VPC-native cluster, private endpoint, private nodes
- **5.4.1**: GKE Metadata Server

### Non-compliant Configuration (`noncompliant/`)

**Purpose**: Demonstrates security anti-patterns that violate CIS GKE Benchmark controls for testing policy detection capabilities.

**Security Violations**:
- ❌ Public GKE control plane endpoint
- ❌ No audit logging components enabled
- ❌ Unencrypted application secrets (no `database_encryption` block)
- ❌ Node pool uses Compute Engine default service account
- ❌ Missing resource labels
- ❌ Permissive firewall rule (SSH from `0.0.0.0/0`)
- ❌ Wildcard IAM role binding (`roles/owner`) on node-pool SA
- ❌ No Container Analysis API enabled — no image scanning
- ❌ `image_type = UBUNTU`, Shielded GKE Nodes disabled, no Workload Metadata config

**CIS Controls Violated**:
- **2.1.1–2.1.3**: No audit logging or retention policies
- **4.1.1–4.1.4**: Overprivileged IAM bindings
- **5.1.1**: No image scanning
- **5.10.1**: No application-layer secrets encryption
- **5.6.4–5.6.5**: Public endpoint and node placement
- **5.5.1–5.5.2 / 5.4.1**: Insecure node configuration

## Policy Validation Results

### Performance Summary

| Metric | Compliant Configuration | Non-compliant Configuration |
|--------|------------------------|----------------------------|
| **Total Policies** | 23 | 23 |
| **Success Rate** | **~91%** (21/23 policies) | **~85%** detection rate |
| **Coverage** | Infrastructure security controls | Security violation detection |

### Policy Categories

#### Fully Validated Controls

**Control Plane Security**:
- ✅ Audit logging configuration (CIS 2.1.1–2.1.3)
- ✅ Authorization mode validation (CIS 2.2.1)

**Encryption & Data Protection**:
- ✅ Cloud KMS application-layer secrets encryption (CIS 5.10.1)
- ✅ CMEK on Secret Manager (CIS 5.3.2)

**Container & Image Security**:
- ✅ Artifact Registry + Container Analysis (CIS 5.1.1)
- ✅ Artifact Registry access minimization (CIS 5.1.2)

**Network Security**:
- ✅ Network policy support (CIS 4.3.1 / 5.6.7)
- ✅ Private endpoint configuration (CIS 5.6.4)
- ✅ Private worker node placement (CIS 5.6.5)
- ✅ Firewall rule validation (CIS 5.6.1)
- ✅ VPC-native cluster (CIS 5.6.2)

**Worker Node Security**:
- ✅ Hardened node image, Shielded GKE Nodes, GKE Metadata Server (CIS 5.5.1, 5.5.2, 5.4.1)

**Resource Management**:
- ✅ Resource label requirements
- ✅ Workload Identity (CIS 5.8.1)
- ✅ Node-pool autoscaling bounds (CIS 5.5.2)

**Access Control (Partial)**:
- ✅ Basic IAM binding validation (CIS 4.1.1, 4.1.2, 4.1.4)
- ⚠️ Complex custom-role permission analysis (CIS 4.1.3, 4.1.8)

#### Plan-time Validation Scope

**Strengths**:
- Infrastructure resource configuration validation
- Resource relationship and dependency verification
- Security setting compliance checks
- Encryption and networking control validation

**Limitations**:
- Complex IAM custom-role permission analysis requires runtime validation
- Kubernetes RBAC resources not present in infrastructure plans
- Dynamic security configurations need cluster-level validation
- Advanced privilege escalation scenarios require behavioral analysis

## Implementation Details

### CIS Benchmark Mapping

| CIS Control | Policy Name | Validation Scope | Implementation |
|-------------|-------------|------------------|----------------|
| 2.1.1 | enable-audit-logs | Control Plane | `logging_config.enable_components` |
| 2.1.2 | audit-log-destinations | Control Plane | `google_logging_project_sink` |
| 2.1.3 | audit-log-retention | Control Plane | `google_logging_project_bucket_config.retention_days` |
| 4.1.1–4.1.4 | minimize-* permissions | IAM | Project IAM bindings + custom-role permissions |
| 5.1.1 | image-scanning | Monitoring | Artifact Registry + Container Analysis |
| 5.10.1 | application-secrets-encryption | Encryption | `database_encryption` + Cloud KMS |
| 5.6.1 | firewall-rules | Networking | `google_compute_firewall` |
| 5.6.2 | vpc-native-cluster | Networking | `ip_allocation_policy` + secondary ranges |
| 5.6.4 | private-endpoint | Networking | `private_cluster_config.enable_private_endpoint` |
| 5.6.5 | private-nodes | Networking | `private_cluster_config.enable_private_nodes` |
| 5.6.7 | network-policy | Networking | `network_policy.enabled` / Dataplane V2 |
| 5.5.1 | node-image-type | Worker Nodes | `image_type` ∈ `{COS_CONTAINERD, UBUNTU_CONTAINERD}` |
| 5.5.2 | shielded-nodes | Worker Nodes | `shielded_instance_config` |
| 5.4.1 | gke-metadata-server | Worker Nodes | `workload_metadata_config.mode == "GKE_METADATA"` |
| 5.8.1 | workload-identity | Cluster Config | `workload_identity_config.workload_pool` |

### Resource Architecture

**Compliant Configuration Resources**:
- 1 VPC (custom-mode) with explicit subnetwork
- 1 private subnetwork with secondary IP ranges (Pods, Services)
- 1 GKE Standard cluster with private nodes + private endpoint, Workload Identity, application-layer secrets encryption, Binary Authorization, network policy
- 1 GKE node pool with `COS_CONTAINERD`, Shielded Nodes, GKE Metadata Server, autoscaling bounds, dedicated service account
- 1 dedicated node-pool service account with least-privilege role bindings
- 1 workload service account + Workload Identity binding
- 1 Cloud KMS key ring + crypto key with rotation
- 1 Artifact Registry repository + Container Analysis API enablement
- 1 Secret Manager secret with CMEK replication
- 1 Cloud Logging sink + project log bucket with ≥ 90-day retention
- 1 Kubernetes NetworkPolicy (default deny)

**Non-compliant Configuration Resources**:
- VPC with default settings; permissive firewall rule (`0.0.0.0/0` → SSH)
- GKE cluster with public endpoint, no audit logging components, no application-layer secrets encryption, legacy ABAC enabled
- Node pool in default-SA mode, `image_type = UBUNTU`, Shielded Nodes disabled, no GKE Metadata Server
- `roles/owner` IAM binding on the node-pool SA
- Secret Manager secret with automatic replication (no CMEK)
- No Container Analysis API enabled; no log sink; no Kubernetes NetworkPolicy

## Usage Instructions

### Testing Configurations

```bash
# Test both configurations against all policies
./scripts/test-opentofu-policies.sh

# Test specific configuration
cd opentofu/compliant
tofu plan -out=tofuplan.binary -var project_id=cis-gke-compliant
tofu show -json tofuplan.binary > tofuplan.json
```

### Generating New Plans

```bash
# Update compliant configuration
cd compliant/
tofu plan -refresh=false -out=tofuplan.binary -var project_id=cis-gke-compliant
tofu show -json tofuplan.binary > tofuplan.json

# Update non-compliant configuration
cd ../noncompliant/
tofu plan -refresh=false -out=tofuplan.binary -var project_id=cis-gke-noncompliant
tofu show -json tofuplan.binary > tofuplan.json
```

### Policy Validation

```bash
# Run specific policy test
kyverno-json scan --policy ../../policies/opentofu/cluster-config/require-labels.yaml --payload tofuplan.json

# Validate encryption policies
kyverno-json scan --policy ../../policies/opentofu/encryption/ --payload tofuplan.json
```

## Development Guidelines

### Configuration Standards

**Compliant Configuration Requirements**:
- All resources that support labels must include `environment` and `owner`
- Security configurations must follow CIS GKE recommendations
- Encryption must be enabled for all data stores (Cloud KMS for cluster, Secret Manager replication)
- Network access must be minimized (private cluster, private nodes, master authorized networks)
- IAM permissions must follow least-privilege principle (predefined roles, no `roles/owner` on workloads)

**Non-compliant Configuration Requirements**:
- Must violate specific CIS controls for testing
- Should include common security misconfigurations
- Must maintain infrastructure functionality
- Should represent realistic security violations

### Policy Development

**Best Practices**:
- Focus on infrastructure resource attributes
- Use simple presence/absence validation logic
- Validate resource relationships and dependencies
- Include clear violation messages
- Test against both configuration types

**Testing Requirements**:
- Policies must pass on compliant configurations
- Policies must fail on non-compliant configurations
- Validation logic must be deterministic
- Performance must be acceptable for CI/CD integration

## Integration Patterns

### CI/CD Pipeline Integration

```yaml
# Example GitHub Actions workflow
- name: Validate OpenTofu Compliance
  run: |
    cd opentofu/compliant
    tofu plan -refresh=false -out=plan.binary -var project_id=cis-gke-compliant
    tofu show -json plan.binary > plan.json
    ../scripts/test-opentofu-policies.sh
```

### Multi-layer Validation

**Plan-time (OpenTofu)**: Infrastructure configuration validation
**Runtime (Kubernetes)**: RBAC and pod security validation
**Continuous (Monitoring)**: Behavioral and configuration drift detection

### Compliance Reporting

- Generate compliance reports with policy results
- Track compliance metrics over time
- Integrate with security dashboards
- Export results to compliance management systems

## Related Documentation

- [CIS GKE Benchmark v1.6.0](../CIS_GKE_Benchmark_v1.6.0.md)
- [Kyverno JSON Documentation](https://kyverno.github.io/kyverno-json/)
- [Policy Directory](../policies/opentofu/)
- [Testing Scripts](../scripts/)
- [Project README](../README.md)

## Support and Contribution

For questions, issues, or contributions:
1. Review existing policies and configurations
2. Test changes against both configuration types
3. Update documentation with any modifications
4. Ensure compliance metrics are maintained or improved

This framework provides a foundation for infrastructure security compliance validation and can be extended to support additional CIS controls and security requirements.
