# Testing Guide

This document explains the testing strategy and how to run tests for the DriftHound GitHub Action.

## Overview

The action uses a multi-layered testing approach:

1. **Unit Tests** - Test individual shell scripts in isolation
2. **Integration Tests** - Test the action as a whole in GitHub Actions workflows
3. **Linting** - Shellcheck for shell script quality
4. **Documentation Tests** - Verify documentation structure

## Running Tests Locally

### Prerequisites

Install required tools:

```bash
# macOS
brew install jq yq shellcheck

# Ubuntu/Debian
sudo apt-get install jq shellcheck
# Install yq manually (see below)
```

Install yq (if not available via package manager):

```bash
YQ_VERSION="v4.35.1"
sudo wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
sudo chmod +x /usr/local/bin/yq
```

### Unit Tests

Run the unit test suite for parse-config.sh:

```bash
./tests/unit/test-parse-config.sh
```

This will run 11 tests covering:
- Basic configuration parsing
- Environment filtering
- Scope filtering (single and multiple)
- Tool extraction
- Terragrunt dependency detection
- Error handling

**Expected output:**
```
Testing: Parse simple configuration
✓ Simple config parsed correctly

Testing: Filter scopes by environment (production)
✓ Production environment filter works correctly

...

=======================================
Test Summary
=======================================
Total tests run: 11
Passed: 11
All tests passed!
```

### Manual Testing

You can manually test the parse-config script:

```bash
export CONFIG_FILE="drifthound.yaml.example"
export WORKING_DIR="."
export ENVIRONMENT_FILTER="production"
export GITHUB_OUTPUT="/tmp/test_output"

bash scripts/parse-config.sh
```

Then inspect the output:

```bash
cat /tmp/test_output
```

### Shellcheck

Run shellcheck on all shell scripts:

```bash
shellcheck scripts/*.sh tests/unit/*.sh
```

## CI/CD Testing

The action runs automated tests on every push and pull request via [`.github/workflows/test.yml`](../.github/workflows/test.yml).

### Test Jobs

1. **unit-tests** - Runs the unit test suite
2. **integration-parse-config** - Tests configuration parsing with real examples
3. **integration-matrix** - Tests matrix generation functionality
4. **shellcheck** - Lints shell scripts
5. **check-docs** - Verifies documentation structure
6. **test-summary** - Aggregates results and displays summary

### Viewing Test Results

1. Go to the Actions tab in GitHub
2. Click on the latest workflow run
3. View the summary for a high-level overview
4. Click on individual jobs for detailed logs

## Test Fixtures

Test fixtures are located in [`tests/fixtures/`](../tests/fixtures/):

| Fixture | Purpose |
|---------|---------|
| `simple-config.yaml` | Basic single-scope configuration |
| `multi-environment.yaml` | Multiple environments (prod/staging/dev) |
| `terragrunt-terraform.yaml` | Terragrunt with Terraform specified |
| `terragrunt-opentofu.yaml` | Terragrunt with OpenTofu specified |
| `terragrunt-default.yaml` | Terragrunt with no underlying tool (defaults to Terraform) |

## Writing New Tests

### Adding Unit Tests

Edit [`tests/unit/test-parse-config.sh`](../tests/unit/test-parse-config.sh):

```bash
# Test N: Description
test_header "Your test description"
export CONFIG_FILE="your-fixture.yaml"
export WORKING_DIR="$FIXTURES_DIR"
export YOUR_FILTER="value"
> "$GITHUB_OUTPUT"  # Clear output

if output=$(bash "$PARSE_SCRIPT" 2>&1); then
  # Extract and verify outputs
  SCOPES_JSON=$(extract_output "scopes" "$GITHUB_OUTPUT")
  # ... assertions ...

  if [[ condition ]]; then
    pass "Test passed"
  else
    fail "Test failed" "Error message"
  fi
else
  fail "Test failed" "Script error: $output"
fi
```

### Adding Test Fixtures

Create a new YAML file in [`tests/fixtures/`](../tests/fixtures/):

```yaml
tool_versions:
  terraform: "1.6.0"

scopes:
  - name: "test-scope"
    project: "test-project"
    environment: "test"
    directory: "./test"
    tool: "terraform"
```

## Test Coverage

Current test coverage:

### parse-config.sh

- ✅ Simple configuration parsing
- ✅ Environment-based filtering
- ✅ Single scope filtering
- ✅ Multiple scope filtering
- ✅ Tool extraction (unique tools)
- ✅ Terragrunt + Terraform detection
- ✅ Terragrunt + OpenTofu detection
- ✅ Terragrunt default behavior
- ✅ Invalid environment handling
- ✅ Invalid scope warnings
- ✅ GITHUB_OUTPUT format

### Matrix Generator

- ✅ Matrix generation for environment
- ✅ Output format validation
- ✅ Scope count verification

### Documentation

- ✅ README.md in root
- ✅ docs/ folder structure
- ✅ All required docs present

### Not Yet Covered

- ❌ setup-tools.sh (tool installation logic)
- ❌ run-drift-checks.sh (execution logic)
- ❌ End-to-end drift detection (requires DriftHound instance)

## Testing Best Practices

1. **Isolation** - Each test should be independent and not rely on previous tests
2. **Fixtures** - Use test fixtures instead of modifying real config files
3. **Cleanup** - Always clean up temporary files (handled by trap in current tests)
4. **Descriptive Names** - Test names should clearly describe what's being tested
5. **Error Messages** - Failed tests should provide clear error messages
6. **Exit Codes** - Tests should exit with non-zero on failure

## Debugging Failed Tests

### Test Output

Each test outputs:
- `✓` Green checkmark for passed tests
- `✗` Red X for failed tests with error message
- Test summary at the end

### Debugging Tips

1. **Add debug output:**
   ```bash
   echo "DEBUG: Variable value: $MY_VAR" >&2
   ```

2. **Run script in debug mode:**
   ```bash
   bash -x scripts/parse-config.sh
   ```

3. **Inspect GITHUB_OUTPUT:**
   ```bash
   cat "$GITHUB_OUTPUT"
   ```

4. **Check jq/yq syntax:**
   ```bash
   echo "$JSON" | jq '.'
   echo "$YAML" | yq '.'
   ```

## Future Testing Improvements

Potential enhancements:

1. **Tool Installation Tests** - Unit tests for setup-tools.sh
2. **Mock DriftHound API** - Integration tests without real DriftHound instance
3. **Performance Tests** - Measure execution time for large configurations
4. **Security Tests** - Test handling of secrets and credentials
5. **Cross-platform Tests** - Test on different OS versions
6. **Coverage Reports** - Generate test coverage metrics

## Troubleshooting

### Tests fail with "command not found: jq"

Install jq:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### Tests fail with "command not found: yq"

Install yq manually:
```bash
YQ_VERSION="v4.35.1"
sudo wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
sudo chmod +x /usr/local/bin/yq
```

### Tests pass locally but fail in CI

Check that:
1. You're using the same yq version as CI
2. Your local environment matches Ubuntu (CI uses ubuntu-latest)
3. You've committed all fixture files
4. Line endings are Unix-style (LF not CRLF)

### JSON parsing errors

Usually caused by:
1. Malformed JSON from yq conversion
2. Incorrect heredoc extraction
3. Empty or null values

Debug with:
```bash
echo "$JSON" | jq '.' 2>&1
```

## Contributing Tests

When contributing new features:

1. Add unit tests to [`tests/unit/`](../tests/unit/)
2. Add integration tests to [`.github/workflows/test.yml`](../.github/workflows/test.yml)
3. Add test fixtures to [`tests/fixtures/`](../tests/fixtures/)
4. Update this documentation with new tests
5. Ensure all tests pass before submitting PR

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.
