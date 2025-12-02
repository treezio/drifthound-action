# DriftHound CLI Improvements for CI/CD

This document outlines potential improvements to the `drifthound-cli` to better support the GitHub Action and CI/CD workflows in general.

## Current State

The current CLI at [drifthound/bin/drifthound-cli](../drifthound/bin/drifthound-cli) works well but has some areas for improvement to better support monorepo and CI/CD scenarios.

## Suggested Improvements

### 1. Environment Variable Support

**Current:** CLI requires all options via command-line flags
**Suggested:** Support environment variables as alternatives

```bash
# Current approach
drifthound --tool=terraform --project=my-project --token=XXX ...

# Suggested improvement
export DRIFTHOUND_TOOL=terraform
export DRIFTHOUND_PROJECT=my-project
export DRIFTHOUND_TOKEN=XXX
drifthound --dir=./terraform
```

**Benefits:**
- Easier to use in CI/CD environments
- More secure (tokens in env vars vs command line)
- Reduces verbosity in scripts

**Implementation:**
```ruby
opts[:tool] ||= ENV['DRIFTHOUND_TOOL']
opts[:project] ||= ENV['DRIFTHOUND_PROJECT']
opts[:token] ||= ENV['DRIFTHOUND_TOKEN']
opts[:api_url] ||= ENV['DRIFTHOUND_API_URL']
opts[:environment] ||= ENV['DRIFTHOUND_ENVIRONMENT']
opts[:slack_channel] ||= ENV['DRIFTHOUND_SLACK_CHANNEL']
```

### 2. Exit Code Conventions

**Current:** Exits with 1 if API response is 400+
**Suggested:** Use different exit codes for different scenarios

```
0 = Success (no drift)
1 = General error
2 = Drift detected
3 = API error
4 = Tool execution error
```

**Benefits:**
- Allows CI/CD to differentiate between "drift detected" and "error occurred"
- Enables more sophisticated workflow logic
- Better for alerting and monitoring

### 3. JSON Output Mode

**Current:** Human-readable output only
**Suggested:** Add `--output=json` flag for machine-readable output

```bash
drifthound --tool=terraform --project=my-project --output=json
```

Output:
```json
{
  "status": "drift",
  "add_count": 2,
  "change_count": 1,
  "destroy_count": 0,
  "duration": 8.2,
  "api_response": {
    "status": 201,
    "message": "Check created successfully"
  }
}
```

**Benefits:**
- Easier to parse in scripts
- Better for GitHub Actions outputs
- Enables sophisticated post-processing

### 4. Quiet Mode

**Current:** Always outputs full plan
**Suggested:** Add `--quiet` flag to suppress plan output

```bash
drifthound --tool=terraform --quiet
```

**Benefits:**
- Cleaner CI/CD logs
- Only show summary, not full plan
- Full plan still available in DriftHound dashboard

### 5. Detailed Exit Code Mode

**Suggested:** Support Terraform's `-detailed-exitcode` behavior

```
0 = No changes (no drift)
1 = Error occurred
2 = Changes detected (drift)
```

This aligns with Terraform's exit codes and is familiar to users.

### 6. Configuration File Support

**Suggested:** Allow configuration via file

```bash
# .drifthoundrc or drifthound.config.json
{
  "api_url": "https://drifthound.example.com",
  "project": "my-project",
  "environment": "production"
}

drifthound --tool=terraform --dir=./terraform
```

**Benefits:**
- DRY - don't repeat configuration
- Easier to manage across multiple projects
- Can be committed to repo

### 7. Retry Logic

**Suggested:** Add `--retry` flag for API failures

```bash
drifthound --tool=terraform --retry=3 --retry-delay=5
```

**Benefits:**
- Handles transient network issues
- More reliable in CI/CD
- Configurable retry attempts

### 8. Timeout Configuration

**Suggested:** Add `--timeout` flag for long-running plans

```bash
drifthound --tool=terraform --timeout=600  # 10 minutes
```

**Benefits:**
- Prevents hung CI/CD jobs
- Configurable per project
- Returns proper error on timeout

### 9. Pre-flight Checks

**Suggested:** Add validation before running

- Check if tool is installed
- Verify API connectivity
- Validate token
- Check if directory exists

```bash
drifthound --validate
# Checks configuration without running plan
```

**Benefits:**
- Fail fast
- Better error messages
- Easier debugging

### 10. Structured Logging

**Suggested:** Add log levels and structured output

```bash
drifthound --log-level=debug --log-format=json
```

**Benefits:**
- Better debugging
- Integration with logging systems
- Easier to parse errors

## Priority Recommendations

For the GitHub Action specifically, the most valuable improvements would be:

1. **Environment variable support** (HIGH) - Makes CI/CD integration much easier
2. **Exit code conventions** (HIGH) - Enables better workflow logic
3. **JSON output mode** (MEDIUM) - Better integration with GitHub Actions
4. **Quiet mode** (MEDIUM) - Cleaner logs
5. **Retry logic** (LOW) - Nice to have for reliability

## Implementation Notes

These improvements should be:
- **Backward compatible** - Don't break existing usage
- **Optional** - Use sensible defaults
- **Well documented** - Update CLI documentation
- **Tested** - Add tests for new features

## Example Enhanced CLI Usage

```bash
# Using environment variables
export DRIFTHOUND_API_URL="https://drifthound.example.com"
export DRIFTHOUND_TOKEN="secret-token"

# Run with JSON output and exit code conventions
drifthound \
  --tool=terraform \
  --project=my-app \
  --environment=production \
  --dir=./terraform \
  --output=json \
  --quiet \
  --retry=3

# Check exit code
if [ $? -eq 2 ]; then
  echo "Drift detected!"
elif [ $? -eq 0 ]; then
  echo "No drift"
else
  echo "Error occurred"
fi
```

## Feedback Welcome

These are suggestions based on GitHub Action development. Actual implementation should consider:
- Existing user workflows
- Maintainability
- Ruby best practices
- DriftHound roadmap
