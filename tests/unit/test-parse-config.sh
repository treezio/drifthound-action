#!/bin/bash
# Unit tests for parse-config.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  echo -e "  ${RED}Error:${NC} $2"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_header() {
  echo ""
  echo -e "${YELLOW}Testing:${NC} $1"
  TESTS_RUN=$((TESTS_RUN + 1))
}

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PARSE_SCRIPT="$PROJECT_ROOT/scripts/parse-config.sh"
FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures"

# Mock GITHUB_OUTPUT for testing
export GITHUB_OUTPUT="/tmp/github_output_$$"
touch "$GITHUB_OUTPUT"

cleanup() {
  rm -f "$GITHUB_OUTPUT"
}
trap cleanup EXIT

# Helper to extract JSON from heredoc format in GITHUB_OUTPUT
extract_output() {
  local key=$1
  local file=$2
  awk "/^${key}<<EOF$/,/^EOF$/" "$file" | sed '1d;$d'
}

# Test 1: Parse simple configuration
test_header "Parse simple configuration"
export CONFIG_FILE="simple-config.yaml"
export WORKING_DIR="$FIXTURES_DIR"
unset ENVIRONMENT_FILTER SINGLE_SCOPE SCOPE_FILTER

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  # Check if tools were extracted correctly
  TOOLS_JSON=$(extract_output "tools" "$GITHUB_OUTPUT")
  TOOLS=$(echo "$TOOLS_JSON" | jq -r '.tools[]')
  if [[ "$TOOLS" == "terraform" ]]; then
    pass "Simple config parsed correctly"
  else
    fail "Simple config parsing" "Expected tool 'terraform', got '$TOOLS'"
  fi
else
  fail "Simple config parsing" "Script failed: $output"
fi

# Test 2: Filter by environment - production
test_header "Filter scopes by environment (production)"
export CONFIG_FILE="multi-environment.yaml"
export WORKING_DIR="$FIXTURES_DIR"
export ENVIRONMENT_FILTER="production"
unset SINGLE_SCOPE SCOPE_FILTER
> "$GITHUB_OUTPUT"  # Clear output file

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  SCOPES_JSON=$(extract_output "scopes" "$GITHUB_OUTPUT")
  SCOPE_COUNT=$(echo "$SCOPES_JSON" | jq '. | length')

  if [[ "$SCOPE_COUNT" -eq 2 ]]; then
    # Verify scope names
    SCOPE_NAMES=$(echo "$SCOPES_JSON" | jq -r '.[].name' | sort)
    EXPECTED="core-prod
networking-prod"
    if [[ "$SCOPE_NAMES" == "$EXPECTED" ]]; then
      pass "Production environment filter works correctly"
    else
      fail "Production environment filter" "Unexpected scope names"
    fi
  else
    fail "Production environment filter" "Expected 2 scopes, got $SCOPE_COUNT"
  fi
else
  fail "Production environment filter" "Script failed: $output"
fi

# Test 3: Filter by environment - staging
test_header "Filter scopes by environment (staging)"
export ENVIRONMENT_FILTER="staging"
> "$GITHUB_OUTPUT"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  SCOPES_JSON=$(extract_output "scopes" "$GITHUB_OUTPUT")
  SCOPE_COUNT=$(echo "$SCOPES_JSON" | jq '. | length')

  if [[ "$SCOPE_COUNT" -eq 1 ]]; then
    SCOPE_NAME=$(echo "$SCOPES_JSON" | jq -r '.[0].name')
    SCOPE_TOOL=$(echo "$SCOPES_JSON" | jq -r '.[0].tool')

    if [[ "$SCOPE_NAME" == "core-staging" ]] && [[ "$SCOPE_TOOL" == "opentofu" ]]; then
      pass "Staging environment filter works correctly"
    else
      fail "Staging environment filter" "Unexpected scope data"
    fi
  else
    fail "Staging environment filter" "Expected 1 scope, got $SCOPE_COUNT"
  fi
else
  fail "Staging environment filter" "Script failed: $output"
fi

# Test 4: Filter by single scope
test_header "Filter by single scope name"
unset ENVIRONMENT_FILTER
export SINGLE_SCOPE="core-dev"
> "$GITHUB_OUTPUT"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  SCOPES_JSON=$(extract_output "scopes" "$GITHUB_OUTPUT")
  SCOPE_COUNT=$(echo "$SCOPES_JSON" | jq '. | length')

  if [[ "$SCOPE_COUNT" -eq 1 ]]; then
    SCOPE_NAME=$(echo "$SCOPES_JSON" | jq -r '.[0].name')
    if [[ "$SCOPE_NAME" == "core-dev" ]]; then
      pass "Single scope filter works correctly"
    else
      fail "Single scope filter" "Expected 'core-dev', got '$SCOPE_NAME'"
    fi
  else
    fail "Single scope filter" "Expected 1 scope, got $SCOPE_COUNT"
  fi
else
  fail "Single scope filter" "Script failed: $output"
fi

# Test 5: Filter by multiple scopes (comma-separated)
test_header "Filter by multiple scope names"
unset SINGLE_SCOPE
export SCOPE_FILTER="core-prod,core-staging"
> "$GITHUB_OUTPUT"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  SCOPES_JSON=$(extract_output "scopes" "$GITHUB_OUTPUT")
  SCOPE_COUNT=$(echo "$SCOPES_JSON" | jq '. | length')

  if [[ "$SCOPE_COUNT" -eq 2 ]]; then
    SCOPE_NAMES=$(echo "$SCOPES_JSON" | jq -r '.[].name' | sort)
    EXPECTED="core-prod
core-staging"
    if [[ "$SCOPE_NAMES" == "$EXPECTED" ]]; then
      pass "Multiple scope filter works correctly"
    else
      fail "Multiple scope filter" "Unexpected scope names"
    fi
  else
    fail "Multiple scope filter" "Expected 2 scopes, got $SCOPE_COUNT"
  fi
else
  fail "Multiple scope filter" "Script failed: $output"
fi

# Test 6: Extract unique tools from multiple scopes
test_header "Extract unique tools from multiple environments"
unset SCOPE_FILTER SINGLE_SCOPE ENVIRONMENT_FILTER
> "$GITHUB_OUTPUT"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  TOOLS_JSON=$(extract_output "tools" "$GITHUB_OUTPUT")
  TOOLS=$(echo "$TOOLS_JSON" | jq -r '.tools | sort | .[]')

  # Should have both terraform and opentofu
  if echo "$TOOLS" | grep -q "opentofu" && echo "$TOOLS" | grep -q "terraform"; then
    pass "Unique tools extracted correctly (terraform + opentofu)"
  else
    fail "Unique tools extraction" "Expected terraform and opentofu, got: $TOOLS"
  fi
else
  fail "Unique tools extraction" "Script failed: $output"
fi

# Test 7: Terragrunt + Terraform
test_header "Terragrunt with Terraform specified"
export CONFIG_FILE="terragrunt-terraform.yaml"
unset ENVIRONMENT_FILTER SINGLE_SCOPE SCOPE_FILTER
> "$GITHUB_OUTPUT"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  TOOLS_JSON=$(extract_output "tools" "$GITHUB_OUTPUT")
  TOOLS=$(echo "$TOOLS_JSON" | jq -r '.tools | sort | .[]')

  # Should have both terraform and terragrunt
  if echo "$TOOLS" | grep -q "terraform" && echo "$TOOLS" | grep -q "terragrunt"; then
    if echo "$output" | grep -q "Using Terraform as Terragrunt's underlying tool"; then
      pass "Terragrunt + Terraform detected correctly"
    else
      fail "Terragrunt + Terraform" "Missing detection message"
    fi
  else
    fail "Terragrunt + Terraform" "Expected terraform and terragrunt, got: $TOOLS"
  fi
else
  fail "Terragrunt + Terraform" "Script failed: $output"
fi

# Test 8: Terragrunt + OpenTofu
test_header "Terragrunt with OpenTofu specified"
export CONFIG_FILE="terragrunt-opentofu.yaml"
> "$GITHUB_OUTPUT"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  TOOLS_JSON=$(extract_output "tools" "$GITHUB_OUTPUT")
  TOOLS=$(echo "$TOOLS_JSON" | jq -r '.tools | sort | .[]')

  # Should have both opentofu and terragrunt
  if echo "$TOOLS" | grep -q "opentofu" && echo "$TOOLS" | grep -q "terragrunt"; then
    if echo "$output" | grep -q "Using OpenTofu as Terragrunt's underlying tool"; then
      pass "Terragrunt + OpenTofu detected correctly"
    else
      fail "Terragrunt + OpenTofu" "Missing detection message"
    fi
  else
    fail "Terragrunt + OpenTofu" "Expected opentofu and terragrunt, got: $TOOLS"
  fi
else
  fail "Terragrunt + OpenTofu" "Script failed: $output"
fi

# Test 9: Terragrunt default (no terraform/opentofu specified)
test_header "Terragrunt with default (should add Terraform)"
export CONFIG_FILE="terragrunt-default.yaml"
> "$GITHUB_OUTPUT"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  TOOLS_JSON=$(extract_output "tools" "$GITHUB_OUTPUT")
  TOOLS=$(echo "$TOOLS_JSON" | jq -r '.tools | sort | .[]')

  # Should default to terraform + terragrunt
  if echo "$TOOLS" | grep -q "terraform" && echo "$TOOLS" | grep -q "terragrunt"; then
    if echo "$output" | grep -q "defaulting to Terraform for Terragrunt"; then
      pass "Terragrunt defaults to Terraform correctly"
    else
      fail "Terragrunt default" "Missing default detection message"
    fi
  else
    fail "Terragrunt default" "Expected terraform and terragrunt, got: $TOOLS"
  fi
else
  fail "Terragrunt default" "Script failed: $output"
fi

# Test 10: Invalid environment filter (should fail)
test_header "Invalid environment filter (should fail gracefully)"
export CONFIG_FILE="multi-environment.yaml"
export ENVIRONMENT_FILTER="nonexistent"
unset SINGLE_SCOPE SCOPE_FILTER
> "$GITHUB_OUTPUT"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  fail "Invalid environment filter" "Should have failed but succeeded"
else
  if echo "$output" | grep -q "No scopes found with environment='nonexistent'"; then
    pass "Invalid environment filter fails with proper error"
  else
    fail "Invalid environment filter" "Failed but with unexpected error: $output"
  fi
fi

# Test 11: Invalid scope filter (should warn and continue)
test_header "Invalid scope in filter (should warn)"
unset ENVIRONMENT_FILTER
export SCOPE_FILTER="core-prod,nonexistent-scope"
> "$GITHUB_OUTPUT"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  if echo "$output" | grep -q "warning.*nonexistent-scope"; then
    SCOPES_JSON=$(extract_output "scopes" "$GITHUB_OUTPUT")
    SCOPE_COUNT=$(echo "$SCOPES_JSON" | jq '. | length')

    if [[ "$SCOPE_COUNT" -eq 1 ]]; then
      pass "Invalid scope filter warns and continues with valid scopes"
    else
      fail "Invalid scope filter" "Should have 1 valid scope, got $SCOPE_COUNT"
    fi
  else
    fail "Invalid scope filter" "Should warn about invalid scope"
  fi
else
  fail "Invalid scope filter" "Script failed unexpectedly: $output"
fi

# Test 12: Default tool applied to scopes without tool field
test_header "Default tool applied to scopes"
export CONFIG_FILE="default-tool.yaml"
unset ENVIRONMENT_FILTER SINGLE_SCOPE SCOPE_FILTER
> "$GITHUB_OUTPUT"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  SCOPES_JSON=$(extract_output "scopes" "$GITHUB_OUTPUT")

  # Check that scope-with-default-tool has terragrunt
  SCOPE1_TOOL=$(echo "$SCOPES_JSON" | jq -r '.[] | select(.name == "scope-with-default-tool") | .tool')
  # Check that scope-with-override has terraform (not the default)
  SCOPE2_TOOL=$(echo "$SCOPES_JSON" | jq -r '.[] | select(.name == "scope-with-override") | .tool')
  # Check that another-default has terragrunt
  SCOPE3_TOOL=$(echo "$SCOPES_JSON" | jq -r '.[] | select(.name == "another-default") | .tool')

  if [[ "$SCOPE1_TOOL" == "terragrunt" ]] && [[ "$SCOPE2_TOOL" == "terraform" ]] && [[ "$SCOPE3_TOOL" == "terragrunt" ]]; then
    if echo "$output" | grep -q "Default tool set to: terragrunt"; then
      pass "Default tool applied correctly and overrides work"
    else
      fail "Default tool" "Missing default tool detection message"
    fi
  else
    fail "Default tool" "Expected terragrunt/terraform/terragrunt, got: $SCOPE1_TOOL/$SCOPE2_TOOL/$SCOPE3_TOOL"
  fi
else
  fail "Default tool" "Script failed: $output"
fi

# Test 13: Missing tool field without default_tool (should fail)
test_header "Missing tool field without default_tool (should fail)"
export CONFIG_FILE="simple-config.yaml"
> "$GITHUB_OUTPUT"

# Temporarily modify simple-config.yaml to remove tool field from a scope
TEMP_CONFIG="/tmp/test-config-no-tool-$$"
yq eval 'del(.scopes[0].tool)' "$FIXTURES_DIR/simple-config.yaml" > "$TEMP_CONFIG"
export CONFIG_FILE="$TEMP_CONFIG"
export WORKING_DIR="/"

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  fail "Missing tool without default" "Should have failed but succeeded"
else
  if echo "$output" | grep -q "missing the 'tool' field and no default_tool is set"; then
    pass "Missing tool field fails with proper error"
  else
    fail "Missing tool without default" "Failed but with unexpected error: $output"
  fi
fi

# Cleanup temp file
rm -f "$TEMP_CONFIG"

# Reset env vars
export WORKING_DIR="$FIXTURES_DIR"
unset CONFIG_FILE

# Print summary
echo ""
echo "======================================="
echo -e "${YELLOW}Test Summary${NC}"
echo "======================================="
echo "Total tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
