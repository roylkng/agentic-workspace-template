"""
Smoke Tests — Service Health Endpoints

Verifies all services defined in workspace.yaml are reachable
and responding on their health endpoints.

Run:  pytest tests/smoke/test_health.py -v -m smoke
"""
import pytest
import httpx

from conftest import WORKSPACE_CONFIG


def _get_health_targets():
    """Build (service_name, url) tuples from workspace.yaml."""
    targets = []
    for svc in WORKSPACE_CONFIG.get("services", []):
        port = svc.get("port", 8080)
        endpoint = svc.get("health_endpoint", "/healthz")
        url = f"http://localhost:{port}{endpoint}"
        targets.append((svc["name"], url))
    return targets


HEALTH_TARGETS = _get_health_targets()


@pytest.mark.smoke
@pytest.mark.parametrize("service_name,url", HEALTH_TARGETS, ids=[t[0] for t in HEALTH_TARGETS])
def test_service_health(service_name, url):
    """Verify {service_name} health endpoint responds with 2xx."""
    if not HEALTH_TARGETS:
        pytest.skip("No services configured in workspace.yaml")

    try:
        response = httpx.get(url, timeout=10)
        assert response.status_code < 400, (
            f"{service_name} health check failed: "
            f"GET {url} returned {response.status_code}"
        )
    except httpx.ConnectError:
        pytest.fail(f"{service_name} not reachable at {url}")
