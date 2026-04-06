"""
Browser Tests — Shared Fixtures

Provides browser/page fixtures for Playwright-based UI testing.
"""
import os
import pytest

# Only import playwright if installed
try:
    from playwright.sync_api import Page
    HAS_PLAYWRIGHT = True
except ImportError:
    HAS_PLAYWRIGHT = False


@pytest.fixture(scope="session")
def portal_url():
    """Base URL for the web UI. Override via PORTAL_URL env var."""
    return os.getenv("PORTAL_URL", "http://localhost:3000")


@pytest.fixture(autouse=True)
def _skip_without_playwright():
    """Skip browser tests if Playwright is not installed."""
    if not HAS_PLAYWRIGHT:
        pytest.skip("playwright not installed — run: pip install pytest-playwright && playwright install")
