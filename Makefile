# =============================================================================
# Agentic Workspace — Makefile
#
# Bootstrap CLI for multi-repo development workspaces.
# Pure shell — no Python dependency. Works on any POSIX system with git + bash.
#
# Usage:
#   make help              Show all targets
#   make init              First-time workspace setup
#   make env-check         Verify environment health
#   make artifact-init     Create artifact directory for a ticket
# =============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Workspace config
WORKSPACE_CONFIG := workspace.yaml
ARTIFACTS_DIR := artifacts
TEMPLATES_DIR := .github/templates
TESTS_DIR := tests

# Timestamp for artifact runs
TIMESTAMP := $(shell date +%Y%m%d-%H%M)

# =============================================================================
# HELP
# =============================================================================

.PHONY: help
help: ## Show this help
	@echo ""
	@echo "  Agentic Workspace"
	@echo ""
	@echo "  Setup:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(init|env-check)' | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Development:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(artifact|snapshot|diff|validate)' | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Testing:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(test)' | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""

# =============================================================================
# SETUP
# =============================================================================

.PHONY: init
init: ## Initialize workspace (run once after cloning)
	@echo ">>> Initializing Agentic Workspace"
	@echo ""
	@command -v git >/dev/null 2>&1 || { echo "ERROR: git required"; exit 1; }
	@echo ">>> Initializing git submodules..."
	@git submodule update --init --recursive
	@mkdir -p $(ARTIFACTS_DIR) docs
	@echo ""
	@echo "Done. Next steps:"
	@echo "  1. Edit workspace.yaml with your project details"
	@echo "  2. Add service repos: git submodule add <url> <service-name>"
	@echo "  3. Ask the agent: 'understand the workspace'"
	@echo "  4. Check health: make env-check"
	@echo ""

.PHONY: env-check
env-check: ## Verify environment health
	@echo ">>> Environment Health Check"
	@echo ""
	@echo "--- Git ---"
	@git submodule status | while read -r line; do \
		sha=$$(echo "$$line" | awk '{print $$1}'); \
		path=$$(echo "$$line" | awk '{print $$2}'); \
		prefix=$$(echo "$$sha" | cut -c1); \
		if [ "$$prefix" = "+" ]; then \
			echo "  Modified: $$path"; \
		elif [ "$$prefix" = "-" ]; then \
			echo "  Uninitialized: $$path"; \
		else \
			echo "  OK: $$path"; \
		fi; \
	done
	@echo ""
	@echo "--- Kubernetes ---"
	@if command -v kubectl >/dev/null 2>&1; then \
		kubectl cluster-info --request-timeout=5s 2>&1 | head -2 || echo "  Cannot reach cluster"; \
		echo ""; \
		echo "--- Unhealthy Pods ---"; \
		kubectl get pods -A --no-headers 2>/dev/null | awk '{ \
			split($$3, ready, "/"); \
			if (ready[1] != ready[2] && $$4 != "Completed") \
				print "  " $$2 " (" $$1 "): " $$4 " " $$3; \
		}' || true; \
	else \
		echo "  kubectl not found — skip"; \
	fi
	@echo ""
	@echo "--- Docker ---"
	@if command -v docker >/dev/null 2>&1; then \
		docker info --format '  Docker {{.ServerVersion}}' 2>/dev/null || echo "  Docker not running"; \
	else \
		echo "  docker not found — skip"; \
	fi
	@echo ""

# =============================================================================
# ARTIFACTS
# =============================================================================

.PHONY: artifact-init
artifact-init: ## Create artifact directory for a ticket (TICKET=KEY)
	@if [ -z "$(TICKET)" ]; then echo "Usage: make artifact-init TICKET=PROJ-1234"; exit 1; fi
	@ARTIFACT_DIR=$(ARTIFACTS_DIR)/$(TICKET)/$(TIMESTAMP); \
	mkdir -p $$ARTIFACT_DIR/screenshots; \
	for tmpl in ticket investigation plan changes test-results submodule-diff; do \
		if [ -f $(TEMPLATES_DIR)/$$tmpl.md ]; then \
			sed 's/{{TICKET_KEY}}/$(TICKET)/g' $(TEMPLATES_DIR)/$$tmpl.md > $$ARTIFACT_DIR/$$tmpl.md; \
		fi; \
	done; \
	echo "Artifacts initialized: $$ARTIFACT_DIR"

.PHONY: validate
validate: ## Validate artifact completeness (TICKET=KEY)
	@if [ -z "$(TICKET)" ]; then echo "Usage: make validate TICKET=PROJ-1234"; exit 1; fi
	@LATEST=$$(ls -td $(ARTIFACTS_DIR)/$(TICKET)/*/ 2>/dev/null | head -1); \
	if [ -z "$$LATEST" ]; then echo "ERROR: No artifacts found for $(TICKET)"; exit 1; fi; \
	echo "Validating: $$LATEST"; \
	MISSING=0; \
	for f in ticket.md investigation.md plan.md changes.md test-results.md; do \
		if [ ! -f "$$LATEST/$$f" ]; then \
			echo "  MISSING: $$f"; MISSING=$$((MISSING+1)); \
		elif [ ! -s "$$LATEST/$$f" ]; then \
			echo "  EMPTY:   $$f"; \
		else \
			echo "  OK:      $$f"; \
		fi; \
	done; \
	if [ $$MISSING -gt 0 ]; then echo ""; echo "$$MISSING file(s) missing."; exit 1; fi; \
	echo ""; echo "All artifacts present."

# =============================================================================
# SUBMODULE TRACKING
# =============================================================================

.PHONY: snapshot
snapshot: ## Capture submodule state as JSON (TICKET=KEY to save, or stdout)
	@JSON="{"; FIRST=1; \
	git submodule status | while read -r sha path rest; do \
		sha=$$(echo "$$sha" | sed 's/^[+-]//'); \
		name=$$(basename "$$path"); \
		if [ $$FIRST -eq 0 ]; then JSON="$$JSON,"; fi; \
		JSON="$$JSON \"$$name\": {\"sha\": \"$$sha\", \"path\": \"$$path\"}"; \
		FIRST=0; \
	done; \
	JSON="$$JSON }"; \
	if [ -n "$(TICKET)" ]; then \
		LATEST=$$(ls -td $(ARTIFACTS_DIR)/$(TICKET)/*/ 2>/dev/null | head -1); \
		if [ -n "$$LATEST" ]; then \
			echo "$$JSON" > "$$LATEST/submodules-before.json"; \
			echo "Saved to: $$LATEST/submodules-before.json"; \
		else echo "$$JSON"; fi; \
	else echo "$$JSON"; fi

.PHONY: snapshot-after
snapshot-after: ## Capture post-change submodule state (TICKET=KEY)
	@if [ -z "$(TICKET)" ]; then echo "Usage: make snapshot-after TICKET=PROJ-1234"; exit 1; fi
	@JSON="{"; FIRST=1; \
	git submodule status | while read -r sha path rest; do \
		sha=$$(echo "$$sha" | sed 's/^[+-]//'); \
		name=$$(basename "$$path"); \
		if [ $$FIRST -eq 0 ]; then JSON="$$JSON,"; fi; \
		JSON="$$JSON \"$$name\": {\"sha\": \"$$sha\", \"path\": \"$$path\"}"; \
		FIRST=0; \
	done; \
	JSON="$$JSON }"; \
	LATEST=$$(ls -td $(ARTIFACTS_DIR)/$(TICKET)/*/ 2>/dev/null | head -1); \
	if [ -n "$$LATEST" ]; then \
		echo "$$JSON" > "$$LATEST/submodules-after.json"; \
		echo "Saved to: $$LATEST/submodules-after.json"; \
	else echo "ERROR: No artifact directory for $(TICKET)"; exit 1; fi

.PHONY: diff
diff: ## Show submodule changes for a ticket (TICKET=KEY)
	@if [ -z "$(TICKET)" ]; then echo "Usage: make diff TICKET=PROJ-1234"; exit 1; fi
	@LATEST=$$(ls -td $(ARTIFACTS_DIR)/$(TICKET)/*/ 2>/dev/null | head -1); \
	if [ -z "$$LATEST" ]; then echo "ERROR: No artifacts for $(TICKET)"; exit 1; fi; \
	BEFORE="$$LATEST/submodules-before.json"; \
	AFTER="$$LATEST/submodules-after.json"; \
	if [ ! -f "$$BEFORE" ] || [ ! -f "$$AFTER" ]; then \
		echo "Need both before and after snapshots."; \
		echo "  make snapshot TICKET=$(TICKET)"; \
		echo "  make snapshot-after TICKET=$(TICKET)"; \
		exit 1; \
	fi; \
	echo "Submodule changes for $(TICKET):"; \
	echo ""; \
	diff "$$BEFORE" "$$AFTER" || echo "(files differ — see above)"

# =============================================================================
# TESTING
# =============================================================================

.PHONY: test-smoke
test-smoke: ## Health endpoint checks (<30s)
	@echo ">>> Smoke Tests"
	@cd $(TESTS_DIR) && python -m pytest smoke/ -v -m smoke --timeout=30 2>/dev/null || \
		echo "No smoke tests found or pytest not installed. See tests/README.md"

.PHONY: test-api
test-api: ## API endpoint integration tests
	@echo ">>> API Tests"
	@cd $(TESTS_DIR) && python -m pytest api/ -v -m api --timeout=60 2>/dev/null || \
		echo "No API tests found or pytest not installed. See tests/README.md"

.PHONY: test-browser
test-browser: ## Browser/UI tests (Playwright)
	@echo ">>> Browser Tests"
	@cd $(TESTS_DIR) && python -m pytest browser/ -v -m browser --timeout=120 2>/dev/null || \
		echo "No browser tests found or pytest not installed. See tests/README.md"

.PHONY: test-contract
test-contract: ## Cross-service API contract tests
	@echo ">>> Contract Tests"
	@cd $(TESTS_DIR) && python -m pytest contract/ -v -m contract --timeout=60 2>/dev/null || \
		echo "No contract tests found or pytest not installed. See tests/README.md"

.PHONY: test-e2e
test-e2e: ## End-to-end workflow tests
	@echo ">>> E2E Tests"
	@cd $(TESTS_DIR) && python -m pytest e2e/ -v -m e2e --timeout=120 2>/dev/null || \
		echo "No e2e tests found or pytest not installed. See tests/README.md"

.PHONY: test-security
test-security: ## Security tests (auth, injection, access control)
	@echo ">>> Security Tests"
	@cd $(TESTS_DIR) && python -m pytest security/ -v -m security --timeout=60 2>/dev/null || \
		echo "No security tests found or pytest not installed. See tests/README.md"

.PHONY: test-quick
test-quick: test-smoke ## Alias for test-smoke (fast sanity check)

.PHONY: test-full
test-full: ## Run all test suites
	@echo ">>> Full Test Suite"
	@cd $(TESTS_DIR) && python -m pytest -v --timeout=120 2>/dev/null || \
		echo "No tests found or pytest not installed. See tests/README.md"
