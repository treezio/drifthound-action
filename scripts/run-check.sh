#!/bin/bash
set -euo pipefail

echo "::group::Running drift checks"

if [[ -z "${SCOPES_JSON:-}" ]]; then
  echo "::error::SCOPES_JSON environment variable is not set"
  exit 1
fi

if [[ -z "${DRIFTHOUND_URL:-}" ]]; then
  echo "::error::DRIFTHOUND_URL environment variable is not set"
  exit 1
fi

if [[ -z "${DRIFTHOUND_TOKEN:-}" ]]; then
  echo "::error::DRIFTHOUND_TOKEN environment variable is not set"
  exit 1
fi

WORKING_DIR="${WORKING_DIR:-.}"
RESULTS_FILE="/tmp/drifthound-results-$$.json"

# Initialize results
RESULTS_JSON='{
  "drift_detected": false,
  "scopes_run": 0,
  "scopes_with_drift": 0,
  "scopes": []
}'

# Get scope count
SCOPE_COUNT=$(echo "$SCOPES_JSON" | jq '. | length')
echo "Running checks for $SCOPE_COUNT scope(s)..."

# Process each scope
for i in $(seq 0 $((SCOPE_COUNT - 1))); do
  SCOPE=$(echo "$SCOPES_JSON" | jq -r ".[$i]")

  SCOPE_NAME=$(echo "$SCOPE" | jq -r '.name')
  PROJECT=$(echo "$SCOPE" | jq -r '.project')
  ENVIRONMENT=$(echo "$SCOPE" | jq -r '.environment')
  DIRECTORY=$(echo "$SCOPE" | jq -r '.directory')
  TOOL=$(echo "$SCOPE" | jq -r '.tool')
  SLACK_CHANNEL=$(echo "$SCOPE" | jq -r '.slack_channel // empty')

  echo ""
  echo "=========================================="
  echo "Running scope: $SCOPE_NAME"
  echo "  Project: $PROJECT"
  echo "  Environment: $ENVIRONMENT"
  echo "  Directory: $DIRECTORY"
  echo "  Tool: $TOOL"
  if [[ -n "$SLACK_CHANNEL" ]]; then
    echo "  Slack Channel: $SLACK_CHANNEL"
  fi
  echo "=========================================="

  # Build full directory path
  FULL_DIR="$WORKING_DIR/$DIRECTORY"

  if [[ ! -d "$FULL_DIR" ]]; then
    echo "::error::Directory not found: $FULL_DIR"
    SCOPE_RESULT=$(jq -n \
      --arg name "$SCOPE_NAME" \
      --arg status "error" \
      --arg error "Directory not found: $FULL_DIR" \
      '{name: $name, status: $status, error: $error, add_count: 0, change_count: 0, destroy_count: 0, duration: 0}')

    RESULTS_JSON=$(echo "$RESULTS_JSON" | jq --argjson scope "$SCOPE_RESULT" '.scopes += [$scope] | .scopes_run += 1')
    continue
  fi

  # Build drifthound command
  DRIFTHOUND_CMD=(
    drifthound
    "--tool=$TOOL"
    "--project=$PROJECT"
    "--environment=$ENVIRONMENT"
    "--token=$DRIFTHOUND_TOKEN"
    "--api-url=$DRIFTHOUND_URL"
    "--dir=$FULL_DIR"
  )

  if [[ -n "$SLACK_CHANNEL" ]]; then
    DRIFTHOUND_CMD+=("--slack-channel=$SLACK_CHANNEL")
  fi

  echo "Running: ${DRIFTHOUND_CMD[*]}"

  # Run drifthound and capture output
  START_TIME=$(date +%s)
  if OUTPUT=$("${DRIFTHOUND_CMD[@]}" 2>&1); then
    EXIT_CODE=0
  else
    EXIT_CODE=$?
  fi
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  echo "$OUTPUT"

  # Parse the output to extract status and counts
  # The drifthound-cli already sends to API, but we need to track locally too
  STATUS="unknown"
  ADD_COUNT=0
  CHANGE_COUNT=0
  DESTROY_COUNT=0

  if echo "$OUTPUT" | grep -q "No changes\|No drift detected"; then
    STATUS="ok"
  elif echo "$OUTPUT" | grep -qE "[0-9]+ to add"; then
    STATUS="drift"
    ADD_COUNT=$(echo "$OUTPUT" | grep -oP '\d+(?= to add)' | head -1 || echo "0")
    CHANGE_COUNT=$(echo "$OUTPUT" | grep -oP '\d+(?= to change)' | head -1 || echo "0")
    DESTROY_COUNT=$(echo "$OUTPUT" | grep -oP '\d+(?= to destroy)' | head -1 || echo "0")
  elif echo "$OUTPUT" | grep -qi "error"; then
    STATUS="error"
  fi

  # Check API response
  if echo "$OUTPUT" | grep -q "Response: 2"; then
    echo "✓ Successfully reported to DriftHound API"
  else
    echo "::warning::Failed to report to DriftHound API"
    STATUS="error"
  fi

  # Build scope result
  SCOPE_RESULT=$(jq -n \
    --arg name "$SCOPE_NAME" \
    --arg status "$STATUS" \
    --argjson add "$ADD_COUNT" \
    --argjson change "$CHANGE_COUNT" \
    --argjson destroy "$DESTROY_COUNT" \
    --argjson duration "$DURATION" \
    '{name: $name, status: $status, add_count: $add, change_count: $change, destroy_count: $destroy, duration: $duration}')

  # Update results
  RESULTS_JSON=$(echo "$RESULTS_JSON" | jq --argjson scope "$SCOPE_RESULT" '.scopes += [$scope] | .scopes_run += 1')

  # Update drift detection flag
  if [[ "$STATUS" == "drift" ]]; then
    RESULTS_JSON=$(echo "$RESULTS_JSON" | jq '.drift_detected = true | .scopes_with_drift += 1')
    echo "⚠️  Drift detected in scope: $SCOPE_NAME"
  elif [[ "$STATUS" == "ok" ]]; then
    echo "✓ No drift in scope: $SCOPE_NAME"
  elif [[ "$STATUS" == "error" ]]; then
    echo "✗ Error in scope: $SCOPE_NAME"
  fi

  echo ""
done

# Save results to file
echo "$RESULTS_JSON" | jq '.' > "$RESULTS_FILE"

echo "::endgroup::"

# Output summary
echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "Scopes checked: $(echo "$RESULTS_JSON" | jq -r '.scopes_run')"
echo "Scopes with drift: $(echo "$RESULTS_JSON" | jq -r '.scopes_with_drift')"
echo "Drift detected: $(echo "$RESULTS_JSON" | jq -r '.drift_detected')"
echo "=========================================="

# Set output
echo "results-file=$RESULTS_FILE" >> $GITHUB_OUTPUT
