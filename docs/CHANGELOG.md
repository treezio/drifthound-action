# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of DriftHound GitHub Action
- Support for Terraform, OpenTofu, and Terragrunt
- YAML-based configuration with `drifthound.yaml`
- Sequential and parallel (matrix) execution modes
- Automatic tool installation
- Scope filtering capabilities
- Comprehensive GitHub Actions summaries
- Slack notification support per scope
- Rich outputs for downstream actions
- Complete documentation and examples
- Matrix generator for parallel execution
- Example workflows for various scenarios

### Features
- Multi-tool support (Terraform, OpenTofu, Terragrunt)
- Monorepo-friendly design
- Configurable tool versions
- Selective scope execution
- fail-on-drift option
- Custom config file paths
- Cloud provider authentication examples

## [1.0.0] - YYYY-MM-DD (Upcoming)

Initial release.

[Unreleased]: https://github.com/treezio/drifthound-action/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/treezio/drifthound-action/releases/tag/v1.0.0
