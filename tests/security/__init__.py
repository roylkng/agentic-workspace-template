# Security Tests — Auth, Injection, Access Control
#
# Verifies security properties:
# - Auth endpoints reject invalid tokens
# - Multi-tenant isolation (org A can't see org B's data)
# - Input validation (SQL injection, XSS payloads rejected)
# - Sensitive data not leaked in responses/logs
#
# Run: pytest -m security
# Or:  make test-security
