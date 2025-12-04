# Tests

This directory contains test suites for validating infrastructure code.

## Directory Structure

```text
tests/
├── ansible/            # Ansible role tests using Molecule
├── helm/               # Helm chart tests
└── integration/        # End-to-end integration tests
```

## Ansible Tests (Molecule)

```bash
cd ansible/roles/microk8s
molecule test
```

## Helm Tests

```bash
# Lint all charts
helm lint charts/fundamental-stack

# Run chart tests (after install)
helm test fundamental
```

## Integration Tests

Integration tests validate the full deployment pipeline.

```bash
# Run integration tests
./tests/integration/run-tests.sh
```

## CI Integration

All tests are run automatically via GitHub Actions on:

- Pull requests
- Pushes to main branch
