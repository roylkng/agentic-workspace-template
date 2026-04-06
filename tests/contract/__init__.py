# Contract Tests — Cross-Service API Contract Verification
#
# Verifies that service-to-service API contracts hold:
# - Request/response schemas match expectations
# - Status codes are correct for known inputs
# - Auth headers are forwarded correctly
#
# Run: pytest -m contract
# Or:  make test-contract
