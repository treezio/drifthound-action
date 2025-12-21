# Quick Start Guide

Get DriftHound GitHub Action running in 5 minutes!

## Prerequisites

- A GitHub repository with Terraform/OpenTofu/Terragrunt code
- Access to a DriftHound instance
- A DriftHound API token

## Step 1: Create Configuration File

Create `drifthound.yaml` in your repository root:

```yaml
tool_versions:
  terraform: "1.6.0"

scopes:
  - name: "my-infrastructure"
    project: "my-app"
    environment: "production"
    directory: "./terraform"
    tool: "terraform"
```

## Step 2: Add GitHub Secrets

Go to your repository settings → Secrets and add:

- `DRIFTHOUND_URL` - Your DriftHound API URL
- `DRIFTHOUND_TOKEN` - Your API token
- Cloud provider credentials (e.g., `AWS_ROLE_ARN`)

## Step 3: Create Workflow

Create `.github/workflows/drift-detection.yml`:

```yaml
name: Drift Detection

on:
  schedule:
    - cron: '0 */6 * * *'
  workflow_dispatch:

jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Run drift detection
        uses: drifthoundhq/drifthound-action@v1
        with:
          drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
          drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
```

## Step 4: Test It

1. Go to Actions tab in your GitHub repository
2. Find "Drift Detection" workflow
3. Click "Run workflow"
4. Wait for completion
5. Check the summary for results

## That's It!

Your drift detection is now automated. The workflow will:
- Run every 6 hours
- Check your infrastructure for drift
- Report results to DriftHound
- Display a summary in GitHub Actions

## Next Steps

- **Add more scopes** - Monitor multiple projects/environments
- **Enable parallel execution** - Use matrix strategy for speed
- **Configure Slack** - Get notifications on drift
- **Customize schedule** - Adjust cron timing
- **Filter scopes** - Run specific checks on demand

See [README.md](../README.md) for advanced configuration options.

## Troubleshooting

**Q: Workflow fails with "401 Unauthorized"**
A: Check your `DRIFTHOUND_TOKEN` secret is correct

**Q: Terraform/OpenTofu not found**
A: The action installs tools automatically - check your `tool` name in config

**Q: Directory not found**
A: Verify the `directory` path in `drifthound.yaml` is correct

**Q: No drift reported to DriftHound**
A: Check the workflow logs for API response errors

## Need Help?

- [Full Documentation](../README.md)
- [Examples](../examples/)
- [GitHub Issues](https://github.com/drifthoundhq/drifthound-action/issues)
