# Documentation

This directory contains documentation and supporting material for the CIS GKE Kyverno Compliance Framework.

## 📚 Available Documentation

### Visual Documentation
- **diagrams/** - Architecture diagrams supporting the documentation

## 🚀 Getting Started

- Review [policy structure](../policies/README.md) for implementation details
- Check [test framework](../tests/README.md) for comprehensive test scenarios
- Use [automation scripts](../scripts/README.md) for testing and validation
- Explore [compliant configurations](../opentofu/compliant/) for production examples
- Review [non-compliant configurations](../opentofu/noncompliant/) for testing scenarios

## 🏗️ Framework Components

- **Policies**: Kyverno policies organized by CIS control sections (Kubernetes runtime + OpenTofu plan-time)
- **Tests**: Per-policy compliant/noncompliant test scenarios
- **Scripts**: Automation tools for testing and reporting
- **OpenTofu**: Example configurations for compliant and non-compliant GKE clusters
- **Custom CIS Scanner**: DaemonSet that performs node-level filesystem and kubelet checks (GKE Standard only)

## 📋 CIS GKE Benchmark Reference

The framework implements automated validation for the majority of applicable CIS GKE Benchmark v1.6.0 controls using Kyverno policies and the included node scanner. See [`../CIS_GKE_Benchmark_v1.6.0.md`](../CIS_GKE_Benchmark_v1.6.0.md) for the section-by-section alignment summary.
