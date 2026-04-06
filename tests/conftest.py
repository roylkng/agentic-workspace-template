"""
Agentic Workspace — Shared Test Fixtures

Provides common fixtures used across all test types.
Reads service configuration from workspace.yaml.
"""
import os
import pytest
import yaml


def _load_workspace_config():
    """Load workspace.yaml from the workspace root."""
    workspace_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    config_path = os.path.join(workspace_root, "workspace.yaml")
    if os.path.exists(config_path):
        with open(config_path) as f:
            return yaml.safe_load(f)
    return {}


WORKSPACE_CONFIG = _load_workspace_config()


def pytest_addoption(parser):
    """Add custom CLI options."""
    parser.addoption(
        "--slow", action="store_true", default=False, help="Include slow tests"
    )


def pytest_collection_modifyitems(config, items):
    """Skip slow tests unless --slow is passed."""
    if config.getoption("--slow"):
        return
    skip_slow = pytest.mark.skip(reason="use --slow to run")
    for item in items:
        if "slow" in item.keywords:
            item.add_marker(skip_slow)


@pytest.fixture(scope="session")
def workspace_config():
    """Workspace configuration from workspace.yaml."""
    return WORKSPACE_CONFIG


@pytest.fixture(scope="session")
def services(workspace_config):
    """List of service definitions from workspace.yaml."""
    return workspace_config.get("services", [])


@pytest.fixture(scope="session")
def workspace_root():
    """Absolute path to the workspace root directory."""
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


@pytest.fixture
def service_url(request):
    """
    Build a service URL from workspace.yaml.

    Usage in test:
        def test_health(service_url):
            url = service_url("backend-api")
            # returns http://localhost:8080
    """
    config = WORKSPACE_CONFIG

    def _get_url(service_name):
        for svc in config.get("services", []):
            if svc["name"] == service_name:
                port = svc.get("port", 8080)
                return f"http://localhost:{port}"
        raise ValueError(f"Service '{service_name}' not found in workspace.yaml")

    return _get_url
