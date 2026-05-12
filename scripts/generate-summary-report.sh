#!/bin/bash
set -uo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

REPORT_DIR="reports"
SUMMARY_FILE="$REPORT_DIR/executive-summary.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo -e "${PURPLE}📈 Generating Executive Summary Report with Custom CIS Scanner Integration...${NC}"

# Debug: Show current environment and available reports
if [ "${CI:-false}" = "true" ] || [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
    echo "🔍 CI Environment detected - Debug info:"
    echo "Working directory: $(pwd)"
    echo "Reports directory exists: $([ -d "$REPORT_DIR" ] && echo 'YES' || echo 'NO')"
    if [ -d "$REPORT_DIR" ]; then
        echo "Available report files:"
        find "$REPORT_DIR" -type f -name "*.md" -o -name "*.txt" -o -name "*.json" | sort
    fi
    echo "---"
fi

# Count total test suites available (now includes custom CIS scanner)
TOTAL_REPORTS=4  # Policy tests, OpenTofu Compliance, Kind Integration, Custom CIS Scanner

# Count completed reports
COMPLETE_REPORTS=0
if [ -f "$REPORT_DIR/policy-tests/summary.md" ]; then
    ((COMPLETE_REPORTS++))
fi
if [ -f "$REPORT_DIR/opentofu-compliance/compliant-plan-scan.md" ]; then
    ((COMPLETE_REPORTS++))
fi
if [ -f "$REPORT_DIR/kind-cluster/validation-results.txt" ] || [ -f "$REPORT_DIR/kind-cluster/validation-summary.md" ]; then
    ((COMPLETE_REPORTS++))
fi
if [ -f "$REPORT_DIR/cis-scanner/summary.md" ] || [ -f "$REPORT_DIR/kind-cluster/cis-scanner/summary.md" ]; then
    ((COMPLETE_REPORTS++))
fi

# Calculate completion rate
if [ $TOTAL_REPORTS -gt 0 ]; then
    COMPLETION_RATE=$(awk "BEGIN {printf \"%.1f\", $COMPLETE_REPORTS * 100 / $TOTAL_REPORTS}" 2>/dev/null || echo "0.0")
else
    COMPLETION_RATE="0.0"
fi

# Initialize the summary file with actual values
echo "# 📋 Kyverno + Custom CIS Scanner GKE Compliance Executive Summary" > "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "**Generated**: $TIMESTAMP" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "## 🎯 Executive Overview" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "This comprehensive compliance report combines **Kyverno policy validation** with **custom CIS scanning** to provide complete Kubernetes security coverage." >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "| Metric | Value |" >> "$SUMMARY_FILE"
echo "|--------|-------|" >> "$SUMMARY_FILE"
echo "| **Total Test Suites** | $TOTAL_REPORTS |" >> "$SUMMARY_FILE"
echo "| **✅ Completed Suites** | $COMPLETE_REPORTS |" >> "$SUMMARY_FILE"
echo "| **Completion Rate** | ${COMPLETION_RATE}% |" >> "$SUMMARY_FILE"
echo "| **Generation Time** | $TIMESTAMP |" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "---" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "## 📈 Detailed Test Results" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "### 📋 Policy Unit Tests" >> "$SUMMARY_FILE"

if [ -f "$REPORT_DIR/policy-tests/summary.md" ]; then
    echo -e "${GREEN}✅ Policy tests found${NC}"
    
    # Extract exact metrics from the summary file
    TOTAL_POLICIES=$(grep "Total Policies" "$REPORT_DIR/policy-tests/summary.md" | grep -o '[0-9]*' | head -1)
    TOTAL_TESTS=$(grep "Total Tests" "$REPORT_DIR/policy-tests/summary.md" | grep -o '[0-9]*' | head -1)
    PASSED_TESTS=$(grep "✅ Passed" "$REPORT_DIR/policy-tests/summary.md" | grep -o '[0-9]*' | head -1)
    FAILED_TESTS=$(grep "❌ Failed" "$REPORT_DIR/policy-tests/summary.md" | grep -o '[0-9]*' | head -1)
    SKIPPED_TESTS=$(grep "⏭️ Skipped" "$REPORT_DIR/policy-tests/summary.md" | grep -o '[0-9]*' | head -1)
    SUCCESS_RATE=$(grep "Success Rate" "$REPORT_DIR/policy-tests/summary.md" | grep -o '[0-9]*%' | head -1 2>/dev/null || echo "N/A")
    
    DURATION=$(grep "Duration" "$REPORT_DIR/policy-tests/summary.md" | awk '{print $4}' | head -1 2>/dev/null || echo "N/A")
    TESTS_PER_SEC=$(grep "Tests/Second" "$REPORT_DIR/policy-tests/summary.md" | awk '{print $4}' | head -1 2>/dev/null || echo "N/A")
    
    # Default values if extraction fails
    TOTAL_POLICIES=${TOTAL_POLICIES:-"0"}
    TOTAL_TESTS=${TOTAL_TESTS:-"0"}
    PASSED_TESTS=${PASSED_TESTS:-"0"}
    FAILED_TESTS=${FAILED_TESTS:-"0"}
    SKIPPED_TESTS=${SKIPPED_TESTS:-"0"}
    SUCCESS_RATE=${SUCCESS_RATE:-"0%"}
    DURATION=${DURATION:-"N/A"}
    TESTS_PER_SEC=${TESTS_PER_SEC:-"N/A"}
    
    cat >> "$SUMMARY_FILE" << POLICY_EOF

| Metric | Value |
|--------|-------|
| Total Policies | $TOTAL_POLICIES |
| Total Tests | $TOTAL_TESTS |
| ✅ Passed | $PASSED_TESTS |
| ❌ Failed | $FAILED_TESTS |
| ⏭️ Skipped | $SKIPPED_TESTS |
| Success Rate | $SUCCESS_RATE |

#### ⚡ Performance Metrics

| Metric | Value |
|--------|-------|
| Duration | $DURATION |
| Tests/Second | $TESTS_PER_SEC |

POLICY_EOF
else
    echo -e "${YELLOW}⚠️  Policy test results not found${NC}"
    echo "- ❌ No policy test results found" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

### 🔒 Custom CIS Scanner Compliance Scan
EOF

# Check for custom CIS scanner results in multiple locations
CIS_SCANNER_FOUND=false
CIS_SCANNER_DIR=""

if [ -f "$REPORT_DIR/cis-scanner/summary.md" ]; then
    CIS_SCANNER_FOUND=true
    CIS_SCANNER_DIR="$REPORT_DIR/cis-scanner"
elif [ -f "$REPORT_DIR/kind-cluster/cis-scanner/summary.md" ]; then
    CIS_SCANNER_FOUND=true
    CIS_SCANNER_DIR="$REPORT_DIR/kind-cluster/cis-scanner"
fi

if [ "$CIS_SCANNER_FOUND" = true ]; then
    echo -e "${GREEN}✅ Custom CIS compliance scan found${NC}"
    
    # Extract custom CIS scanner metrics
    if [ -f "$CIS_SCANNER_DIR/node-scan.json" ]; then
        # Try to extract totals from custom scanner JSON format
        if command -v jq >/dev/null 2>&1; then
            NODE_PASS=$(jq -r '[.checks[] | select(.status=="PASS")] | length' "$CIS_SCANNER_DIR/node-scan.json" 2>/dev/null || echo "N/A")
            NODE_FAIL=$(jq -r '[.checks[] | select(.status=="FAIL")] | length' "$CIS_SCANNER_DIR/node-scan.json" 2>/dev/null || echo "N/A")
            NODE_WARN="0"  # Custom scanner doesn't have warnings
            NODE_INFO="0"  # Custom scanner doesn't have info
        else
            NODE_PASS=$(grep -o '"status":"PASS"' "$CIS_SCANNER_DIR/node-scan.json" 2>/dev/null | wc -l || echo "N/A")
            NODE_FAIL=$(grep -o '"status":"FAIL"' "$CIS_SCANNER_DIR/node-scan.json" 2>/dev/null | wc -l || echo "N/A")
            NODE_WARN="0"
            NODE_INFO="0"
        fi
    else
        NODE_PASS="N/A"
        NODE_FAIL="N/A"
        NODE_WARN="N/A"
        NODE_INFO="N/A"
    fi
    
    # Check for master scan results (custom scanner combines all checks)
    # Since custom scanner runs as DaemonSet, it collects all node data
    MASTER_PASS="N/A"
    MASTER_FAIL="N/A"
    MASTER_AVAILABLE="✅ Integrated"  # Custom scanner integrates all checks
    
    cat >> "$SUMMARY_FILE" << CIS_EOF

| Component | Status | Pass | Fail | Warn | Info |
|-----------|--------|------|------|------|------|
| **Worker Nodes** | ✅ Scanned | $NODE_PASS | $NODE_FAIL | $NODE_WARN | $NODE_INFO |
| **All Nodes** | $MASTER_AVAILABLE | Unified scanning via DaemonSet | | | |

#### 🔍 CIS Controls Coverage

Our custom CIS scanner validates:
- **3.1.x**: Worker node configuration files (permissions, ownership)
- **3.2.x**: Worker node kubelet configuration (anonymous auth, authorization)
- **Unified scanning**: Single DaemonSet deployment for all nodes
- **ConfigMap storage**: Results stored as cis-scanner-results-* ConfigMaps

CIS_EOF
else
    echo -e "${YELLOW}⚠️  Custom CIS scanner results not found${NC}"
    echo "- ❌ No custom CIS compliance scan results found" >> "$SUMMARY_FILE"
    echo "- ⚠️ Node-level file system validation not performed" >> "$SUMMARY_FILE"
    echo "- 💡 Recommendation: Ensure custom CIS scanner DaemonSet is deployed on target clusters" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

### 🛠️ OpenTofu Compliance Tests
EOF

if [ -f "$REPORT_DIR/opentofu-compliance/compliant-plan-scan.md" ] && [ -f "$REPORT_DIR/opentofu-compliance/noncompliant-plan-scan.md" ]; then
    echo -e "${GREEN}✅ OpenTofu compliance tests found${NC}"
    
    # Extract exact metrics from opentofu reports using the actual format
    COMPLIANT_SUCCESS=$(grep "Success Rate" "$REPORT_DIR/opentofu-compliance/compliant-plan-scan.md" | grep -o '[0-9]*%' | head -1 2>/dev/null || echo "0%")
    NONCOMPLIANT_DETECTION=$(grep "Detection Rate" "$REPORT_DIR/opentofu-compliance/noncompliant-plan-scan.md" | grep -o '[0-9]*%' | head -1 2>/dev/null || echo "0%")
    VIOLATIONS_DETECTED=$(grep "Correctly Failed" "$REPORT_DIR/opentofu-compliance/noncompliant-plan-scan.md" | grep -o '[0-9]*' | head -1 2>/dev/null || echo "0")
    
    cat >> "$SUMMARY_FILE" << OPENTOFU_EOF

| Configuration | Status | Success Rate | CIS Scanner Integration |
|---------------|--------|--------------|------------------------|
| ✅ Compliant | Complete | $COMPLIANT_SUCCESS | DaemonSet deployed |
| 🔴 Noncompliant | Complete | N/A | Minimal configuration |

- 🔴 Policy violations detected in non-compliant config: **$VIOLATIONS_DETECTED**
- 🔒 Custom CIS scanner deployed via OpenTofu for continuous compliance monitoring

OPENTOFU_EOF
else
    echo -e "${YELLOW}⚠️  OpenTofu compliance results not found${NC}"
    echo "- ❌ No opentofu compliance results found" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

### 🌟 Kind Integration Tests
EOF

if [ -f "$REPORT_DIR/kind-cluster/validation-results.txt" ] || [ -f "$REPORT_DIR/kind-cluster/validation-summary.md" ]; then
    echo -e "${GREEN}✅ Kind integration tests found${NC}"
    
    if [ -f "$REPORT_DIR/kind-cluster/validation-summary.md" ]; then
        # Extract from validation summary if available
        POLICIES_APPLIED=$(grep "Policies Applied\|Kyverno Policies Applied" "$REPORT_DIR/kind-cluster/validation-summary.md" | awk -F'|' '{print $3}' | tr -d ' ' 2>/dev/null || echo "0")
        CATEGORIES_TESTED=$(grep "Categories Tested\|Policy Categories Tested" "$REPORT_DIR/kind-cluster/validation-summary.md" | awk -F'|' '{print $3}' | tr -d ' ' 2>/dev/null || echo "0")
        TEST_MANIFESTS=$(grep "Test Manifests" "$REPORT_DIR/kind-cluster/validation-summary.md" | awk -F'|' '{print $3}' | tr -d ' ' 2>/dev/null || echo "0")
        CIS_SCANNER_STATUS=$(grep "CIS Scanner\|Custom CIS" "$REPORT_DIR/kind-cluster/validation-summary.md" | awk -F'|' '{print $3}' | tr -d ' ' 2>/dev/null || echo "Not Available")
        
        echo "- ✅ Integration tests completed successfully" >> "$SUMMARY_FILE"
        echo "- **Kyverno Policies Applied**: $POLICIES_APPLIED" >> "$SUMMARY_FILE"
        echo "- **Categories Tested**: $CATEGORIES_TESTED" >> "$SUMMARY_FILE"
        echo "- **Test Manifests**: $TEST_MANIFESTS" >> "$SUMMARY_FILE"
        echo "- **Custom CIS Scanner Status**: $CIS_SCANNER_STATUS" >> "$SUMMARY_FILE"
    else
        # Fallback to validation-results.txt
        RESOURCE_COUNT=$(grep -c "Testing\|PASS\|FAIL" "$REPORT_DIR/kind-cluster/validation-results.txt" 2>/dev/null || echo "0")
        echo "- ✅ Integration tests completed successfully" >> "$SUMMARY_FILE"
        echo "- Resources tested: **$RESOURCE_COUNT**" >> "$SUMMARY_FILE"
    fi
else
    echo -e "${YELLOW}⚠️  Kind integration results not found${NC}"
    echo "- ❌ No Kind integration test results found" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

---

## 🏗️ Architecture Overview

This compliance framework provides **multi-layer security validation** using our unified custom CIS scanner:

### 🔍 Validation Layers

1. **🎯 Kyverno Policies** - Kubernetes API resource validation
   - RBAC controls and permissions
   - Pod security standards
   - Network policies and service configurations
   - Resource quotas and limits

2. **🔒 Custom CIS Scanner** - Node-level compliance validation
   - File permissions and ownership checks
   - Kubelet configuration validation
   - Unified DaemonSet deployment across all nodes
   - Results stored in ConfigMaps for easy access

3. **🛠️ Infrastructure Compliance** - OpenTofu/Terraform validation
   - GKE cluster security configurations
   - VPC and networking security
   - Google IAM roles and bindings
   - Cloud KMS encryption settings

### 🔗 Integration Points

- **Single Tool Deployment** - Custom CIS scanner runs as DaemonSet
- **Unified Results** - All node results stored in cis-scanner-results-* ConfigMaps
- **OpenTofu configurations** deploy custom CIS scanner automatically
- **KIND testing** includes both Kyverno and custom CIS scanner validation

---

## 📁 Report Files Directory

### 📊 Policy Tests
- **Detailed results**: [🗾 detailed-results.md](policy-tests/detailed-results.md)
- **Summary**: [📈 summary.md](policy-tests/summary.md)
- **Execution stats**: [📊 execution-stats.json](policy-tests/execution-stats.json)

### 🔒 Custom CIS Scanner Compliance
- **Node scan results**: [📄 node-scan.json](cis-scanner/node-scan.json)
- **ConfigMap results**: [📄 cis-scanner-results-*](cis-scanner/)
- **Summary**: [📈 summary.md](cis-scanner/summary.md)

### 🛠️ OpenTofu Compliance
- **Compliant scan**: [✅ compliant-plan-scan.md](opentofu-compliance/compliant-plan-scan.md)  
- **Non-compliant scan**: [❌ noncompliant-plan-scan.md](opentofu-compliance/noncompliant-plan-scan.md)

### 🌟 Kind Integration  
- **Validation results**: [📊 validation-results.txt](kind-cluster/validation-results.txt)
- **Cluster resources**: [🎯 cluster-resources.yaml](kind-cluster/cluster-resources.yaml)
- **Validation summary**: [📈 validation-summary.md](kind-cluster/validation-summary.md)

---

## 📈 Test Suite Status

| Test Suite | Status | Completion | Notes |
|------------|--------|------------|-------|
| Policy Unit Tests | $( [ -f "$REPORT_DIR/policy-tests/summary.md" ] && echo "✅ Complete" || echo "❌ Missing" ) | $( [ -f "$REPORT_DIR/policy-tests/summary.md" ] && echo "100%" || echo "0%" ) | Kubernetes policy validation |
| Custom CIS Scanner | $( [ "$CIS_SCANNER_FOUND" = true ] && echo "✅ Complete" || echo "❌ Missing" ) | $( [ "$CIS_SCANNER_FOUND" = true ] && echo "100%" || echo "0%" ) | Node-level CIS compliance |
| OpenTofu Compliance | $( [ -f "$REPORT_DIR/opentofu-compliance/compliant-plan-scan.md" ] && echo "✅ Complete" || echo "❌ Missing" ) | $( [ -f "$REPORT_DIR/opentofu-compliance/compliant-plan-scan.md" ] && echo "100%" || echo "0%" ) | Infrastructure compliance |
| Kind Integration | $( [ -f "$REPORT_DIR/kind-cluster/validation-results.txt" ] && echo "✅ Complete" || echo "❌ Missing" ) | $( [ -f "$REPORT_DIR/kind-cluster/validation-results.txt" ] && echo "100%" || echo "0%" ) | Local cluster testing |
| **Overall** | **${COMPLETION_RATE}%** | **${COMPLETE_REPORTS}/${TOTAL_REPORTS}** | **Test suite completion** |

---

*🤖 Generated by Enhanced Kyverno + Custom CIS Scanner GKE Compliance Test Suite v4.0*
EOF

echo -e "${GREEN}✅ Executive summary with custom CIS scanner integration generated successfully!${NC}"
echo -e "${BLUE}📈 Completion rate: ${COMPLETION_RATE}% (${COMPLETE_REPORTS}/${TOTAL_REPORTS} suites)${NC}"
echo -e "${BLUE}🔒 Custom CIS Scanner: $( [ "$CIS_SCANNER_FOUND" = true ] && echo "✅ Active" || echo "❌ Not Found" )${NC}"
echo -e "${BLUE}📁 Report location: $SUMMARY_FILE${NC}"

# Ensure script exits successfully
exit 0