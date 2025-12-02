#!/bin/bash
set -euo pipefail

echo "::group::Installing drifthound-cli"

CLI_VERSION="${CLI_VERSION:-main}"
CLI_REPO="${CLI_REPO:-treezio/DriftHound}"
INSTALL_PATH="/usr/local/bin/drifthound"

echo "Installing drifthound-cli from $CLI_REPO@$CLI_VERSION..."

# Download the CLI from GitHub
CLI_URL="https://raw.githubusercontent.com/$CLI_REPO/$CLI_VERSION/bin/drifthound-cli"

echo "Downloading from: $CLI_URL"

if curl -fsSL "$CLI_URL" -o /tmp/drifthound-cli; then
  sudo mv /tmp/drifthound-cli "$INSTALL_PATH"
  sudo chmod +x "$INSTALL_PATH"
  echo "✓ drifthound-cli installed successfully at $INSTALL_PATH"
else
  echo "::error::Failed to download drifthound-cli from $CLI_URL"
  exit 1
fi

# Verify installation
if command -v drifthound &> /dev/null; then
  echo "✓ drifthound-cli is available in PATH"
  drifthound --help || echo "Note: CLI requires arguments to run"
else
  echo "::error::drifthound-cli installation failed"
  exit 1
fi

echo "::endgroup::"
