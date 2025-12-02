#!/bin/bash
set -euo pipefail

echo "::group::Setting up infrastructure tools"

if [[ -z "${TOOLS_JSON:-}" ]]; then
  echo "::error::TOOLS_JSON environment variable is not set"
  exit 1
fi

TOOLS=$(echo "$TOOLS_JSON" | jq -r '.tools[]')
VERSIONS=$(echo "$TOOLS_JSON" | jq -r '.versions')

echo "Tools to install: $(echo "$TOOLS_JSON" | jq -r '.tools | @json')"

# Function to install a specific tool
install_tool() {
  local tool=$1
  local version=${2:-latest}

  case "$tool" in
    terraform)
      echo "Installing Terraform (version: $version)..."
      if [[ "$version" == "latest" ]]; then
        TERRAFORM_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r .tag_name | sed 's/v//')
      else
        TERRAFORM_VERSION="$version"
      fi

      TERRAFORM_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
      echo "Downloading Terraform ${TERRAFORM_VERSION} from $TERRAFORM_URL"

      curl -fsSL "$TERRAFORM_URL" -o /tmp/terraform.zip
      sudo unzip -q -o /tmp/terraform.zip -d /usr/local/bin/
      sudo chmod +x /usr/local/bin/terraform
      rm /tmp/terraform.zip

      terraform version
      ;;

    opentofu)
      echo "Installing OpenTofu (version: $version)..."
      if [[ "$version" == "latest" ]]; then
        OPENTOFU_VERSION=$(curl -s https://api.github.com/repos/opentofu/opentofu/releases/latest | jq -r .tag_name | sed 's/v//')
      else
        OPENTOFU_VERSION="$version"
      fi

      OPENTOFU_URL="https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_amd64.zip"
      echo "Downloading OpenTofu ${OPENTOFU_VERSION} from $OPENTOFU_URL"

      curl -fsSL "$OPENTOFU_URL" -o /tmp/tofu.zip
      sudo unzip -q -o /tmp/tofu.zip -d /usr/local/bin/
      sudo chmod +x /usr/local/bin/tofu
      rm /tmp/tofu.zip

      # Create symlink for 'opentofu' command
      sudo ln -sf /usr/local/bin/tofu /usr/local/bin/opentofu

      tofu version
      ;;

    terragrunt)
      echo "Installing Terragrunt (version: $version)..."
      if [[ "$version" == "latest" ]]; then
        TERRAGRUNT_VERSION=$(curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest | jq -r .tag_name | sed 's/v//')
      else
        TERRAGRUNT_VERSION="$version"
      fi

      TERRAGRUNT_URL="https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"
      echo "Downloading Terragrunt ${TERRAGRUNT_VERSION} from $TERRAGRUNT_URL"

      curl -fsSL "$TERRAGRUNT_URL" -o /tmp/terragrunt
      sudo mv /tmp/terragrunt /usr/local/bin/terragrunt
      sudo chmod +x /usr/local/bin/terragrunt

      terragrunt --version
      ;;

    *)
      echo "::warning::Unknown tool: $tool"
      ;;
  esac
}

# Install each required tool
for tool in $TOOLS; do
  # Check if already installed
  if command -v "$tool" &> /dev/null; then
    echo "✓ $tool is already installed"
    $tool --version || $tool version || echo "(version info unavailable)"
    continue
  fi

  # Get version for this tool from configuration
  TOOL_VERSION=$(echo "$VERSIONS" | jq -r --arg tool "$tool" '.[$tool] // "latest"')

  install_tool "$tool" "$TOOL_VERSION"
  echo "✓ $tool installed successfully"
done

echo "::endgroup::"
