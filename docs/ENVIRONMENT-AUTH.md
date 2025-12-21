# Environment-Based Authentication Guide

This document explains how to handle different credentials for different environments (production, staging, development) when using DriftHound GitHub Action.

## The Problem

Most real-world infrastructure follows security best practices with separate credentials per environment:

```
Production   → AWS Role: arn:aws:iam::111111111111:role/prod-drift-check
Staging      → AWS Role: arn:aws:iam::222222222222:role/staging-drift-check
Development  → AWS Role: arn:aws:iam::333333333333:role/dev-drift-check
```

**You cannot authenticate once and check all environments.** Each environment requires its own credentials.

## The Solution

Create separate GitHub Actions jobs per environment, where each job:
1. Authenticates with environment-specific credentials
2. Runs drift checks for only that environment's scopes

## Implementation Pattern

### Step 1: Organize Your `drifthound.yaml`

Group scopes by environment with clear naming:

```yaml
default_tool: terraform

scopes:
  # Production scopes
  - name: "core-prod"
    environment: "production"
    directory: "./terraform/core"

  - name: "networking-prod"
    environment: "production"
    directory: "./terraform/networking"

  # Staging scopes
  - name: "core-staging"
    environment: "staging"
    directory: "./terraform/core"

  - name: "networking-staging"
    environment: "staging"
    directory: "./terraform/networking"

  # Development scopes
  - name: "core-dev"
    environment: "development"
    directory: "./terraform/core"
```

### Step 2: Create Environment-Specific Jobs

```yaml
name: Drift Detection

on:
  schedule:
    - cron: '0 */6 * * *'  # Check production every 6 hours
    - cron: '0 9 * * *'    # Check staging daily
  workflow_dispatch:

jobs:
  # Production job with production credentials
  production-drift:
    name: Production
    runs-on: ubuntu-latest
    if: github.event.schedule == '0 */6 * * *' || github.event_name == 'workflow_dispatch'
    steps:
      - uses: actions/checkout@v4

      - name: Auth to Production AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_PROD_ROLE }}
          aws-region: us-east-1

      - name: Run production drift checks
        uses: drifthoundhq/drifthound-action@v1
        with:
          drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
          drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
          environment: production  # Simple! Filter by environment field

  # Staging job with staging credentials
  staging-drift:
    name: Staging
    runs-on: ubuntu-latest
    if: github.event.schedule == '0 9 * * *' || github.event_name == 'workflow_dispatch'
    steps:
      - uses: actions/checkout@v4

      - name: Auth to Staging AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_STAGING_ROLE }}
          aws-region: us-east-1

      - name: Run staging drift checks
        uses: drifthoundhq/drifthound-action@v1
        with:
          drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
          drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
          environment: staging  # Simple! Filter by environment field
```

### Step 3: Configure GitHub Secrets

Add environment-specific secrets to your repository:

```
Secrets Required:
├── DRIFTHOUND_URL           # Same for all environments
├── DRIFTHOUND_TOKEN         # Same for all environments
├── AWS_PROD_ROLE            # arn:aws:iam::111111111111:role/prod-drift-check
├── AWS_STAGING_ROLE         # arn:aws:iam::222222222222:role/staging-drift-check
└── AWS_DEV_ROLE             # arn:aws:iam::333333333333:role/dev-drift-check
```

## Benefits of This Pattern

1. **Security** - Each environment uses appropriate, least-privilege credentials
2. **Isolation** - Production drift checks don't depend on staging credentials
3. **Flexibility** - Different schedules per environment (check prod more often)
4. **Clarity** - Clear separation in workflow logs and GitHub Actions UI
5. **Fail Independence** - Staging failures don't block production checks

## Complete Example

See [examples/environment-based.yml](../examples/environment-based.yml) for a fully-featured example including:
- Different schedules per environment
- Manual triggering with environment selection
- Conditional Slack notifications
- Summary job aggregating results
- Proper error handling

## Common Patterns

### Pattern 1: Same Infrastructure, Different AWS Accounts

```yaml
# Production in AWS account 111111111111
production-drift:
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::111111111111:role/drift-check

# Staging in AWS account 222222222222
staging-drift:
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::222222222222:role/drift-check
```

### Pattern 2: Multi-Cloud (AWS + GCP)

```yaml
aws-production-drift:
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_PROD_ROLE }}
    - uses: drifthoundhq/drifthound-action@v1
      with:
        scope-filter: 'aws-core-prod,aws-networking-prod'

gcp-production-drift:
  steps:
    - uses: google-github-actions/auth@v2
      with:
        workload_identity_provider: ${{ secrets.GCP_PROD_PROVIDER }}
    - uses: drifthoundhq/drifthound-action@v1
      with:
        scope-filter: 'gcp-compute-prod,gcp-storage-prod'
```

### Pattern 3: Shared Services + Environment-Specific

```yaml
# Some infrastructure is shared (same credentials)
shared-drift:
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_SHARED_ROLE }}
    - uses: drifthoundhq/drifthound-action@v1
      with:
        scope-filter: 'shared-dns,shared-networking,shared-monitoring'

# Other infrastructure is per-environment
production-drift:
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_PROD_ROLE }}
    - uses: drifthoundhq/drifthound-action@v1
      with:
        scope-filter: 'app-prod,database-prod'
```

## Scope Naming Convention

We recommend a naming convention that makes filtering easy:

```yaml
# Pattern: {component}-{environment}
scopes:
  - name: "core-prod"           # Easy to filter: *-prod
  - name: "networking-prod"
  - name: "database-prod"
  - name: "core-staging"        # Easy to filter: *-staging
  - name: "networking-staging"
  - name: "database-staging"
```

Then in your workflow:

```yaml
# Run all production scopes
scope-filter: 'core-prod,networking-prod,database-prod'

# Or use wildcards in your scripting
# (Note: The action doesn't support wildcards directly, you need to list them)
```

## Anti-Patterns to Avoid

### ❌ Don't: Single Job with Shared Credentials

```yaml
# BAD: This won't work across environments
drift-check:
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE }}  # Which environment?
    - uses: drifthoundhq/drifthound-action@v1
      # This will fail for non-matching environments
```

### ❌ Don't: Re-authenticate Mid-Job

```yaml
# BAD: Actions can't switch credentials mid-job reliably
drift-check:
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_PROD_ROLE }}
    - uses: drifthoundhq/drifthound-action@v1
      with:
        scope-filter: 'core-prod'

    # This doesn't reliably switch credentials
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_STAGING_ROLE }}
    - uses: drifthoundhq/drifthound-action@v1
      with:
        scope-filter: 'core-staging'
```

### ✅ Do: Separate Jobs

```yaml
# GOOD: Clear separation
production:
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_PROD_ROLE }}
    - uses: drifthoundhq/drifthound-action@v1
      with:
        scope-filter: 'core-prod'

staging:
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_STAGING_ROLE }}
    - uses: drifthoundhq/drifthound-action@v1
      with:
        scope-filter: 'core-staging'
```

## FAQ

**Q: Can I run all environments in a matrix?**

A: No, because each environment needs different credentials. You need separate jobs.

**Q: What if I have 10 environments?**

A: Create 10 jobs, or use reusable workflows to reduce duplication.

**Q: Can I check multiple cloud providers in one job?**

A: Only if you authenticate to all providers before running the action. See [examples/monorepo.yml](../examples/monorepo.yml).

**Q: Should I always separate by environment?**

A: Only if your environments require different credentials. If all your scopes use the same credentials, a single job is fine.

## Next Steps

1. Review the complete example: [examples/environment-based.yml](../examples/environment-based.yml)
2. Identify your environment credential boundaries
3. Create separate jobs per credential set
4. Use `scope-filter` to target the right scopes per job
5. Test with a manual workflow_dispatch first

## Need Help?

Open an issue with:
- Your environment structure
- Your authentication approach
- Your drifthound.yaml (redacted)

We'll help you design the right workflow pattern!
