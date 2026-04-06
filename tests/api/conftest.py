"""
API Tests — Shared Fixtures

Provides HTTP client fixtures for API testing.
"""
import pytest
import httpx


@pytest.fixture(scope="session")
def http_client():
    """Shared HTTP client for API tests."""
    with httpx.Client(timeout=30) as client:
        yield client


@pytest.fixture
def auth_headers():
    """
    Override this fixture in your test file to provide service-specific auth.

    Example:
        @pytest.fixture
        def auth_headers():
            return {"Authorization": "Bearer <token>"}
    """
    return {}
