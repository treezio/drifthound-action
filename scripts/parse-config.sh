#!/bin/bash
set -euo pipefail

echo "::group::Parsing configuration"

CONFIG_FILE="${CONFIG_FILE:-drifthound.yaml}"
WORKING_DIR="${WORKING_DIR:-.}"
FULL_CONFIG_PATH="$WORKING_DIR/$CONFIG_FILE"

# Check if config file exists
if [[ ! -f "$FULL_CONFIG_PATH" ]]; then
  echo "::error::Configuration file not found: $FULL_CONFIG_PATH"
  exit 1
fi

echo "Reading configuration from: $FULL_CONFIG_PATH"

# Validate YAML syntax
if ! yq eval '.' "$FULL_CONFIG_PATH" > /dev/null 2>&1; then
  echo "::error::Invalid YAML syntax in $FULL_CONFIG_PATH"
  exit 1
fi

# Check if scopes are defined
SCOPE_COUNT=$(yq eval '.scopes | length' "$FULL_CONFIG_PATH")
if [[ "$SCOPE_COUNT" -eq 0 ]]; then
  echo "::error::No scopes defined in configuration file"
  exit 1
fi

echo "Found $SCOPE_COUNT scope(s) in configuration"

# Filter scopes if requested
SCOPES_TO_RUN=""

if [[ -n "${ENVIRONMENT_FILTER:-}" ]]; then
  # Filter by environment field (RECOMMENDED)
  echo "Filtering to environment: $ENVIRONMENT_FILTER"
  # Use yq to filter and output as JSON array directly
  SCOPES_JSON=$(yq eval "[.scopes[] | select(.environment == \"$ENVIRONMENT_FILTER\")]" "$FULL_CONFIG_PATH" -o=json)

  if [[ -z "$SCOPES_JSON" || "$SCOPES_JSON" == "null" || "$SCOPES_JSON" == "[]" ]]; then
    echo "::error::No scopes found with environment='$ENVIRONMENT_FILTER'"
    exit 1
  fi

  SCOPE_COUNT=$(echo "$SCOPES_JSON" | jq '. | length')
  echo "Found $SCOPE_COUNT scope(s) for environment '$ENVIRONMENT_FILTER'"

elif [[ -n "${SINGLE_SCOPE:-}" ]]; then
  # Single scope specified
  echo "Filtering to single scope: $SINGLE_SCOPE"
  SCOPES_TO_RUN=$(yq eval ".scopes[] | select(.name == \"$SINGLE_SCOPE\")" "$FULL_CONFIG_PATH" | yq eval -o=json '.' -)

  if [[ -z "$SCOPES_TO_RUN" || "$SCOPES_TO_RUN" == "null" ]]; then
    echo "::error::Scope '$SINGLE_SCOPE' not found in configuration"
    exit 1
  fi
  SCOPES_JSON="[$SCOPES_TO_RUN]"

elif [[ -n "${SCOPE_FILTER:-}" ]]; then
  # Multiple scopes specified (comma-separated)
  echo "Filtering to scopes: $SCOPE_FILTER"
  IFS=',' read -ra SCOPE_ARRAY <<< "$SCOPE_FILTER"

  FILTERED_SCOPES=()
  for scope_name in "${SCOPE_ARRAY[@]}"; do
    scope_name=$(echo "$scope_name" | xargs) # trim whitespace
    SCOPE_DATA=$(yq eval ".scopes[] | select(.name == \"$scope_name\")" "$FULL_CONFIG_PATH" | yq eval -o=json '.' -)

    if [[ -z "$SCOPE_DATA" || "$SCOPE_DATA" == "null" ]]; then
      echo "::warning::Scope '$scope_name' not found in configuration, skipping"
      continue
    fi

    FILTERED_SCOPES+=("$SCOPE_DATA")
  done

  if [[ ${#FILTERED_SCOPES[@]} -eq 0 ]]; then
    echo "::error::None of the specified scopes were found in configuration"
    exit 1
  fi

  # Convert array to JSON array
  SCOPES_JSON="["
  for i in "${!FILTERED_SCOPES[@]}"; do
    SCOPES_JSON+="${FILTERED_SCOPES[$i]}"
    if [[ $i -lt $((${#FILTERED_SCOPES[@]} - 1)) ]]; then
      SCOPES_JSON+=","
    fi
  done
  SCOPES_JSON+="]"

else
  # No filter, run all scopes
  echo "Running all scopes"
  SCOPES_JSON=$(yq eval '.scopes' "$FULL_CONFIG_PATH" | yq eval -o=json '.' -)
fi

# Extract unique tools needed
TOOLS_NEEDED=$(echo "$SCOPES_JSON" | jq -r '[.[].tool] | unique | @json')

# Extract tool versions from config
TOOL_VERSIONS_JSON="{}"
if yq eval '.tool_versions' "$FULL_CONFIG_PATH" > /dev/null 2>&1; then
  TOOL_VERSIONS_JSON=$(yq eval '.tool_versions' "$FULL_CONFIG_PATH" | yq eval -o=json '.' -)
  if [[ "$TOOL_VERSIONS_JSON" == "null" ]]; then
    TOOL_VERSIONS_JSON="{}"
  fi
fi

# IMPORTANT: Terragrunt is a wrapper around Terraform or OpenTofu
# If terragrunt is in the tools list, we need to also install its underlying tool
if echo "$TOOLS_NEEDED" | jq -e 'index("terragrunt")' > /dev/null; then
  echo "Terragrunt detected - checking for underlying tool requirement"

  # Check if terraform or opentofu is specified in tool_versions
  HAS_TERRAFORM=$(echo "$TOOL_VERSIONS_JSON" | jq -e '.terraform' > /dev/null && echo "true" || echo "false")
  HAS_OPENTOFU=$(echo "$TOOL_VERSIONS_JSON" | jq -e '.opentofu' > /dev/null && echo "true" || echo "false")

  if [[ "$HAS_TERRAFORM" == "true" ]]; then
    echo "Using Terraform as Terragrunt's underlying tool"
    TOOLS_NEEDED=$(echo "$TOOLS_NEEDED" | jq -r '. + ["terraform"] | unique | @json')
  elif [[ "$HAS_OPENTOFU" == "true" ]]; then
    echo "Using OpenTofu as Terragrunt's underlying tool"
    TOOLS_NEEDED=$(echo "$TOOLS_NEEDED" | jq -r '. + ["opentofu"] | unique | @json')
  else
    echo "No terraform/opentofu version specified - defaulting to Terraform for Terragrunt"
    TOOLS_NEEDED=$(echo "$TOOLS_NEEDED" | jq -r '. + ["terraform"] | unique | @json')
  fi
fi

# Build tools JSON with versions
TOOLS_JSON=$(jq -n \
  --argjson tools "$TOOLS_NEEDED" \
  --argjson versions "$TOOL_VERSIONS_JSON" \
  '{tools: $tools, versions: $versions}')

echo "Tools needed: $(echo "$TOOLS_JSON" | jq -r '.tools | @json')"
echo "Scopes to run: $(echo "$SCOPES_JSON" | jq -r 'length')"

# Debug: Show scopes
echo "Scope details:"
echo "$SCOPES_JSON" | jq -r '.[] | "  - \(.name) (\(.tool)) in \(.directory)"'

# Set outputs
echo "scopes<<EOF" >> $GITHUB_OUTPUT
echo "$SCOPES_JSON" >> $GITHUB_OUTPUT
echo "EOF" >> $GITHUB_OUTPUT

echo "tools<<EOF" >> $GITHUB_OUTPUT
echo "$TOOLS_JSON" >> $GITHUB_OUTPUT
echo "EOF" >> $GITHUB_OUTPUT

echo "::endgroup::"
