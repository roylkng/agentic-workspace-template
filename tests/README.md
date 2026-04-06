# Workspace-Level Tests

This directory contains integration, contract, and end-to-end tests that verify behavior **across service boundaries**. Service-level unit tests live inside each service repo.

## Structure

```
tests/
├── pytest.ini          # Markers, test paths, default options
├── conftest.py         # Shared fixtures (workspace config, service URLs)
├── requirements.txt    # Test dependencies
├── smoke/              # Health endpoint checks (<30s)
├── api/                # Per-service API endpoint tests
├── browser/            # UI tests via Playwright
├── contract/           # Cross-service API contract tests
├── e2e/                # Full workflow tests
└── security/           # Auth, injection, access control tests
```

## Quick Start

```bash
# Install test dependencies
pip install -r tests/requirements.txt

# Run by type
make test-smoke       # Health checks
make test-api         # API integration
make test-browser     # UI tests
make test-contract    # Cross-service contracts
make test-e2e         # End-to-end workflows
make test-security    # Security tests
make test-full        # Everything

# Run a specific file or test
cd tests && pytest api/test_backend.py -v -m api
cd tests && pytest api/test_backend.py::TestPROJ1234::test_bug_repro -v
```

## Adding a Test

### Regression test for a bug (reproduce test)

The dev agent writes these automatically during the reproduce-test step:

```python
# tests/api/test_backend.py

@pytest.mark.api
class TestPROJ1234:
    """Regression test for PROJ-1234: <bug summary>."""

    def test_proj_1234_description(self, service_url, auth_headers):
        url = service_url("backend-api")
        response = httpx.get(f"{url}/api/v1/endpoint", headers=auth_headers)
        assert response.status_code == 200
```

### Contract test (cross-service)

```python
# tests/contract/test_api_gateway_to_backend.py

@pytest.mark.contract
class TestGatewayBackendContract:
    """Verify API gateway forwards requests correctly to backend."""

    def test_auth_header_forwarded(self, service_url, auth_headers):
        # Call gateway, verify backend receives auth
        ...
```

## Markers

| Marker | Purpose | Speed |
|--------|---------|-------|
| `smoke` | Service health checks | <30s |
| `api` | API endpoint tests | 1-5 min |
| `browser` | Playwright UI tests | 2-10 min |
| `contract` | Cross-service contracts | 1-3 min |
| `e2e` | Full workflows | 5-15 min |
| `security` | Security tests | 1-5 min |
| `slow` | Long-running (opt-in) | 15+ min |
