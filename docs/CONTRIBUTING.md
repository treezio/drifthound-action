# Contributing to DriftHound Action

Thank you for your interest in contributing to the DriftHound GitHub Action! This document provides guidelines and instructions for contributing.

## Development Setup

### Prerequisites

- Bash 4.0+
- Git
- A GitHub account
- Access to a DriftHound instance for testing

### Local Development

1. **Fork and Clone**
   ```bash
   git clone https://github.com/YOUR-USERNAME/drifthound-action.git
   cd drifthound-action
   ```

2. **Make Changes**
   - Scripts are in the `scripts/` directory
   - Action definitions are in `action.yml` and `matrix/action.yml`
   - Example workflows are in `examples/`

3. **Test Your Changes**
   Create a test repository with:
   - A `drifthound.yaml` configuration
   - A GitHub Actions workflow that uses your local action
   - Sample Terraform/OpenTofu/Terragrunt code

   Example test workflow:
   ```yaml
   - uses: ./path/to/your/local/action
     with:
       drifthound-url: ${{ secrets.DRIFTHOUND_URL }}
       drifthound-token: ${{ secrets.DRIFTHOUND_TOKEN }}
   ```

## Code Style

### Bash Scripts

- Use `set -euo pipefail` at the top of every script
- Use meaningful variable names in UPPERCASE for environment variables
- Add comments for complex logic
- Use `echo "::group::"` and `echo "::endgroup::"` for collapsible output
- Use `echo "::error::"` for error messages
- Use `echo "::warning::"` for warnings

### YAML Files

- Use 2 spaces for indentation
- Use single quotes for strings containing special characters
- Add comments to explain non-obvious configurations

## Testing Checklist

Before submitting a PR, test:

- [ ] Sequential execution (all scopes)
- [ ] Matrix parallel execution
- [ ] Single scope execution
- [ ] Multiple scopes via scope-filter
- [ ] All three tools: Terraform, OpenTofu, Terragrunt
- [ ] Custom config file path
- [ ] fail-on-drift option
- [ ] Output values are correct
- [ ] GitHub Actions summary is generated
- [ ] Error handling (missing config, invalid scope, etc.)

## Pull Request Process

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Your Changes**
   - Keep commits focused and atomic
   - Write clear commit messages
   - Update documentation if needed

3. **Update Documentation**
   - Update README.md if adding new features
   - Add examples if appropriate
   - Update drifthound.yaml.example if needed

4. **Submit PR**
   - Fill out the PR template
   - Link any related issues
   - Request review from maintainers

## Reporting Issues

When reporting issues, please include:

- GitHub Actions workflow file
- drifthound.yaml configuration
- Relevant error messages or logs
- Expected vs actual behavior
- Steps to reproduce

## Feature Requests

Feature requests are welcome! Please:

- Check if the feature already exists or is planned
- Explain the use case and benefit
- Provide examples if possible
- Be open to discussion and iteration

## Questions?

- Open a [Discussion](https://github.com/drifthoundhq/drifthound-action/discussions)
- Check existing [Issues](https://github.com/drifthoundhq/drifthound-action/issues)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
