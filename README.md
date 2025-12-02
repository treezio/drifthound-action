# DriftHound GitHub Action

A GitHub Action for running infrastructure drift detection with [DriftHound](https://github.com/treezio/DriftHound). This action automates drift checks for Terraform, OpenTofu, and Terragrunt projects in CI/CD pipelines, with first-class support for monorepos.

## Features

- 🔍 **Multi-tool support** - Terraform, OpenTofu, and Terragrunt
- 🏗️ **Monorepo friendly** - Define multiple drift scopes in one configuration
- ⚡ **Parallel execution** - Run checks in parallel using GitHub Actions matrix strategy
- 🎯 **Selective checks** - Run specific scopes or filter by criteria
- 🔐 **Environment-based auth** - Handle different credentials per environment (prod/staging/dev)
- 📊 **Rich reporting** - GitHub Actions summary with detailed drift information
- 🔌 **Extensible outputs** - Integrate with GitHub Issues, deployment gates, metrics systems, and more
- 🔧 **Automatic tool installation** - No need to pre-install Terraform/OpenTofu/Terragrunt
- 🔒 **Secure** - Uses GitHub Actions secrets for sensitive data

## Quick Start

### 1. Create a `drifthound.yaml` configuration file

Create a `drifthound.yaml` file in your repository root:

```yaml
# Optional: Specify tool versions
tool_versions:
  terraform: "1.6.0"
  opentofu: "1.6.0"
  terragrunt: "0.54.0"

# Define drift detection scopes
scopes:
  - name: "core-infrastructure-prod"
    project: "my-app"
    environment: "production"
    directory: "./terraform/core"
    tool: "terraform"
    slack_channel: "#infra-alerts"

  - name: "networking-prod"
    project: "my-app"
    environment: "production"
    directory: "./terraform/networking"
    tool: "terraform"
```

### 2. Create a GitHub Actions workflow

Create `.github/workflows/drift-detection.yml`:

```yaml
name: Infrastructure Drift Detection

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Configure your cloud provider authentication
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      # Run DriftHound
      - name: Run drift detection
        uses: treezio/drifthound-action@v1
        with:
          drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
          drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
```

### 3. Configure secrets

Add these secrets to your GitHub repository:

- `DRIFTHOUND_URL` - Your DriftHound API URL (e.g., `https://drifthound.example.com`)
- `DRIFTHOUND_TOKEN` - Your DriftHound API token
- Cloud provider credentials (AWS, GCP, Azure, etc.)

## Configuration

### `drifthound.yaml` Schema

```yaml
# Optional: Global tool versions
tool_versions:
  terraform: "1.6.0"      # Specific version
  opentofu: "1.6.0"       # Or omit for latest
  terragrunt: "0.54.0"    # Terragrunt version
  # IMPORTANT: If using Terragrunt, you must also specify either terraform or opentofu
  # Terragrunt is a wrapper and requires one of these tools to be installed

# Required: Define scopes
scopes:
  - name: string              # Required: Unique identifier for this scope
    project: string           # Required: Project name in DriftHound
    environment: string       # Required: Environment name in DriftHound
    directory: string         # Required: Path to IaC files (relative to repo root)
    tool: string              # Required: terraform | opentofu | terragrunt
    tool_version: string      # Optional: Override global tool version
    slack_channel: string     # Optional: Slack channel for notifications (e.g., #alerts)
```

## Action Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `drifthound-url` | Yes | - | DriftHound API URL |
| `drifthound-token` | Yes | - | DriftHound API token |
| `config-file` | No | `drifthound.yaml` | Path to configuration file |
| `environment` | No | - | ⭐ Filter scopes by environment (e.g., `production`) |
| `scope` | No | - | Run a single specific scope |
| `scope-filter` | No | - | Comma-separated list of scopes to run |
| `fail-on-drift` | No | `false` | Fail workflow if drift is detected |
| `cli-version` | No | `main` | drifthound-cli version (branch/tag/commit) |
| `cli-repo` | No | `treezio/DriftHound` | Repository containing drifthound-cli |
| `working-directory` | No | `.` | Working directory for the action |

## Action Outputs

| Output | Description |
|--------|-------------|
| `drift-detected` | Whether drift was detected (`true`/`false`) |
| `results` | JSON summary of all drift check results |
| `scopes-run` | Number of scopes executed |
| `scopes-with-drift` | Number of scopes with drift detected |

## Usage Examples

### Simple Sequential Execution

Run all scopes sequentially:

```yaml
- uses: treezio/drifthound-action@v1
  with:
    drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
    drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
```

### Parallel Execution with Matrix Strategy

Run scopes in parallel for faster execution. You can filter by environment:

```yaml
jobs:
  prepare-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.generate.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
      - id: generate
        uses: treezio/drifthound-action/matrix@v1
        with:
          environment: production  # Generate matrix for production only

  drift-check:
    needs: prepare-matrix
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix: ${{ fromJson(needs.prepare-matrix.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_PROD_ROLE }}
      - uses: treezio/drifthound-action@v1
        with:
          drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
          drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
          scope: ${{ matrix.name }}
```

This combines parallel execution with environment-specific authentication!

### Run Specific Scopes

Run only specific scopes:

```yaml
- uses: treezio/drifthound-action@v1
  with:
    drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
    drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
    scope-filter: 'core-infrastructure-prod,networking-prod'
```

### Fail on Drift Detection

Fail the workflow if drift is detected:

```yaml
- uses: treezio/drifthound-action@v1
  with:
    drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
    drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
    fail-on-drift: 'true'
```

### Custom Configuration File

Use a different configuration file:

```yaml
- uses: treezio/drifthound-action@v1
  with:
    drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
    drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
    config-file: 'infra/drift-config.yaml'
```

### Using Outputs

Use action outputs in subsequent steps:

```yaml
- name: Run drift detection
  id: drift
  uses: treezio/drifthound-action@v1
  with:
    drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
    drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}

- name: Process results
  run: |
    echo "Drift detected: ${{ steps.drift.outputs.drift-detected }}"
    echo "Scopes checked: ${{ steps.drift.outputs.scopes-run }}"
    echo "Scopes with drift: ${{ steps.drift.outputs.scopes-with-drift }}"
    echo "Results: ${{ steps.drift.outputs.results }}"
```

## Cloud Provider Authentication

Authenticate to your cloud providers **before** running the DriftHound action:

### AWS Example

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1

- name: Run drift detection
  uses: treezio/drifthound-action@v1
  with:
    drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
    drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
```

### Multiple Environments

**⚠️ Important:** If you have multiple environments (production, staging, development), each typically requires different credentials (e.g., different AWS roles).

**Solution:** Create separate jobs per environment with environment-specific authentication. See the **[Environment Authentication Guide](docs/ENVIRONMENT-AUTH.md)** for detailed patterns.

**Quick example:**
```yaml
jobs:
  production:
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_PROD_ROLE }}
      - uses: treezio/drifthound-action@v1
        with:
          environment: production  # Filter to production scopes
```

### Other Cloud Providers

- **GCP:** Use [`google-github-actions/auth`](https://github.com/google-github-actions/auth)
- **Azure:** Use [`azure/login`](https://github.com/Azure/login)
- **Multiple providers:** See [examples/monorepo.yml](examples/monorepo.yml)

## Advanced Examples

### Scheduled Checks with Different Frequencies

```yaml
on:
  schedule:
    - cron: '0 */6 * * *'   # Production every 6 hours
    - cron: '0 9 * * *'     # Staging daily at 9am
```

### Environment-Specific Workflows

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to check'
        required: true
        type: choice
        options:
          - production
          - staging
          - development

jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: treezio/drifthound-action@v1
        with:
          drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
          drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
          environment: ${{ github.event.inputs.environment }}
```

### Using Action Outputs

The action provides outputs that you can use in subsequent workflow steps:

```yaml
- name: Run drift detection
  id: drift
  uses: treezio/drifthound-action@v1
  with:
    drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
    drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}

# Example 1: Block deployment if drift detected
- name: Block deployment on drift
  if: steps.drift.outputs.drift-detected == 'true'
  run: |
    echo "::error::Drift detected! Blocking deployment."
    exit 1

# Example 2: Create GitHub Issue on drift
- name: Create issue on drift
  if: steps.drift.outputs.drift-detected == 'true'
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.issues.create({
        owner: context.repo.owner,
        repo: context.repo.repo,
        title: '🚨 Infrastructure Drift Detected',
        body: `Drift was detected in ${{ steps.drift.outputs.scopes-with-drift }} scope(s).

        **Details:**
        - Total scopes checked: ${{ steps.drift.outputs.scopes-run }}
        - Scopes with drift: ${{ steps.drift.outputs.scopes-with-drift }}

        View details in [DriftHound](${{ secrets.DRIFTHOUND_URL }}).`,
        labels: ['infrastructure', 'drift']
      });

# Example 3: Add custom metrics/reporting
- name: Send metrics to monitoring system
  run: |
    curl -X POST https://your-metrics-endpoint.com/api/metrics \
      -H "Content-Type: application/json" \
      -d '{
        "drift_detected": "${{ steps.drift.outputs.drift-detected }}",
        "scopes_checked": ${{ steps.drift.outputs.scopes-run }},
        "scopes_with_drift": ${{ steps.drift.outputs.scopes-with-drift }}
      }'
```

## Example Workflows

See the [examples/](examples/) directory for complete workflow examples:

- **[environment-based.yml](examples/environment-based.yml)** - ⭐ **RECOMMENDED**: Sequential checks with environment-specific auth
- **[matrix-with-environment.yml](examples/matrix-with-environment.yml)** - ⭐ **BEST PERFORMANCE**: Parallel checks for one environment
- **[simple.yml](examples/simple.yml)** - Basic sequential execution (single environment)
- **[matrix.yml](examples/matrix.yml)** - Parallel execution with matrix strategy
- **[monorepo.yml](examples/monorepo.yml)** - Complex monorepo with multiple cloud providers

## Documentation

Complete guides and references:

- **[Quick Start Guide](docs/QUICKSTART.md)** - Get started in 5 minutes
- **[Environment Authentication](docs/ENVIRONMENT-AUTH.md)** - Multi-environment setup guide
- **[Testing Guide](docs/TESTING.md)** - Testing strategy and how to run tests
- **[Contributing](docs/CONTRIBUTING.md)** - Contribution guidelines
- **[CLI Improvements](docs/CLI-IMPROVEMENTS.md)** - Suggestions for drifthound-cli
- **[Changelog](docs/CHANGELOG.md)** - Version history

## Monorepo Support

This action is designed with monorepos in mind. You can:

1. **Define multiple scopes** in `drifthound.yaml` for different projects/environments
2. **Run checks in parallel** using the matrix strategy
3. **Filter scopes** to run only what's needed
4. **Mix tools** (Terraform, OpenTofu, Terragrunt) in the same repository
5. **Configure different authentication** per cloud provider

Example monorepo structure:

```
my-monorepo/
├── drifthound.yaml           # Central configuration
├── .github/
│   └── workflows/
│       └── drift-detection.yml
├── terraform/
│   ├── aws-core/
│   ├── aws-networking/
│   └── gcp-services/
├── opentofu/
│   └── azure-storage/
└── terragrunt/
    └── multi-region/
```

## Troubleshooting

### Authentication Errors

**Problem:** `401 Unauthorized` from DriftHound API

**Solution:** Verify your `DRIFTHOUND_TOKEN` secret is correct and hasn't been revoked. Generate a new token if needed.

### Tool Not Found

**Problem:** `command not found: terraform`

**Solution:** The action automatically installs tools based on the scopes being run. Ensure the `tool` field in your config matches exactly: `terraform`, `opentofu`, or `terragrunt`.

**Note on Terragrunt:** Terragrunt is a wrapper around Terraform or OpenTofu. If you use Terragrunt in any scope, the action will also install the underlying tool:
- If `tool_versions.terraform` is specified, Terraform will be installed
- If `tool_versions.opentofu` is specified, OpenTofu will be installed
- If neither is specified, Terraform will be installed by default

### Scope Not Found

**Problem:** `Scope 'my-scope' not found in configuration`

**Solution:** Check the `name` field in your `drifthound.yaml` matches exactly what you're passing to `scope` or `scope-filter`.

### Directory Not Found

**Problem:** `Directory not found: ./terraform/core`

**Solution:** Ensure the `directory` path in your config is relative to the repository root and exists.

### Drift Check Failing

**Problem:** Drift checks fail with Terraform errors

**Solution:**
- Verify cloud provider authentication is configured correctly
- Ensure Terraform state backend is accessible from GitHub Actions
- Check that required environment variables are set
- Review Terraform/OpenTofu/Terragrunt logs in the action output

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for detailed guidelines.

## License

MIT

## Support

- **Documentation:** [DriftHound Docs](https://github.com/treezio/DriftHound)
- **Issues:** [GitHub Issues](https://github.com/treezio/drifthound-action/issues)
- **Discussions:** [GitHub Discussions](https://github.com/treezio/drifthound-action/discussions)

## Related Projects

- [DriftHound](https://github.com/treezio/DriftHound) - The main DriftHound application
- [drifthound-cli](https://github.com/treezio/DriftHound/blob/main/bin/drifthound-cli) - Command-line interface for DriftHound
