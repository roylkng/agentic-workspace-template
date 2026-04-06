# =============================================================================
# Agentic Workspace — Makefile
#
# Bootstrap CLI for multi-repo development workspaces.
# Provides thin convenience targets — the agent handles complex logic at runtime
# by reading workspace.yaml and skill docs directly.
#
# Philosophy: Makefile = bootstrapping; Skills = execution contracts; MCPs = the agent's hands.
#
# Usage:
#   make help              Show all targets
#   make init              First-time workspace setup
#   make add-service       Add a service repo as submodule
#   make env-check         Verify environment health
#   make artifact-init     Create artifact directory for a ticket
# =============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Read workspace config
WORKSPACE_CONFIG := workspace.yaml
PROJECT_NAME := $(shell python3 -c "import yaml; print(yaml.safe_load(open('$(WORKSPACE_CONFIG)'))['project']['name'])" 2>/dev/null || echo "my-project")
ENV_FORMULA := $(shell python3 -c "import yaml; print(yaml.safe_load(open('$(WORKSPACE_CONFIG)'))['environment']['formula'])" 2>/dev/null || echo "custom")
TICKET_PREFIX := $(shell python3 -c "import yaml; print(yaml.safe_load(open('$(WORKSPACE_CONFIG)'))['project']['ticket_prefix'])" 2>/dev/null || echo "PROJ")

# Directories
SERVICES_DIR := services
ARTIFACTS_DIR := artifacts
DOCS_DIR := docs
TEMPLATES_DIR := .github/templates
GENERATED_DIR := .github/generated

# Timestamp for artifact runs
TIMESTAMP := $(shell date +%Y%m%d-%H%M)

# =============================================================================
# SETUP
# =============================================================================

.PHONY: help
help: ## Show this help
	@echo ""
	@echo "  Agentic Workspace: $(PROJECT_NAME)"
	@echo "  Environment: $(ENV_FORMULA)"
	@echo ""
	@echo "  Setup:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(init|add-service|import-services|discover-mcp)' | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Understanding & Docs:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(understand|generate-docs|workspace-info)' | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Development:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(artifact|snapshot|diff|validate)' | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Testing:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(test|env-check)' | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Services:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(logs|restart|deploy|status)' | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""

.PHONY: init
init: ## Initialize workspace (run once after cloning)
	@echo ">>> Initializing Agentic Workspace: $(PROJECT_NAME)"
	@echo ""
	@# Check prerequisites
	@command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "ERROR: git required"; exit 1; }
	@python3 -c "import yaml" 2>/dev/null || { echo "Installing dependencies..."; pip3 install -r requirements.txt; }
	@# Initialize submodules
	@echo ">>> Initializing git submodules..."
	@git submodule update --init --recursive
	@# Create directories
	@mkdir -p $(ARTIFACTS_DIR) $(GENERATED_DIR) $(DOCS_DIR)
	@# Environment-specific init
	@$(MAKE) _init-$(ENV_FORMULA) 2>/dev/null || true
	@echo ""
	@echo "✅ Workspace initialized."
	@echo ""
	@echo "Next steps:"
	@echo "  1. Add services:     make add-service NAME=my-svc REPO=git@github.com:org/my-svc.git"
	@echo "  2. Configure MCP:    make discover-mcp"
	@echo "  3. Understand code:  ask agent 'understand the workspace'"
	@echo "  4. Check health:     make env-check"
	@echo ""

_init-kubernetes:
	@command -v kubectl >/dev/null 2>&1 || echo "WARNING: kubectl not found"
	@kubectl cluster-info --request-timeout=5s >/dev/null 2>&1 && echo ">>> Kubernetes cluster connected" || echo "WARNING: Cannot reach Kubernetes cluster"

_init-docker-compose:
	@command -v docker >/dev/null 2>&1 || echo "WARNING: docker not found"
	@docker info >/dev/null 2>&1 && echo ">>> Docker daemon running" || echo "WARNING: Docker not running"

_init-custom:
	@echo ">>> Custom environment — configure commands in workspace.yaml"

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

.PHONY: add-service
add-service: ## Add a service repo (NAME=x REPO=url [LANG=python|node|go])
	@if [ -z "$(NAME)" ] || [ -z "$(REPO)" ]; then \
		echo "Usage: make add-service NAME=my-svc REPO=git@github.com:org/my-svc.git [LANG=python]"; \
		exit 1; \
	fi
	@echo ">>> Adding service: $(NAME)"
	@git submodule add $(REPO) $(SERVICES_DIR)/$(NAME) 2>/dev/null || \
		{ echo "Submodule may already exist. Updating..."; git submodule update --init $(SERVICES_DIR)/$(NAME); }
	@echo ">>> Detecting language and conventions..."
	@python3 scripts/detect-service.py $(SERVICES_DIR)/$(NAME) $(NAME) $(LANG)
	@echo ""
	@echo "✅ Service '$(NAME)' added at $(SERVICES_DIR)/$(NAME)"
	@echo "   Review the entry in workspace.yaml and adjust as needed."

.PHONY: import-services
import-services: ## Import services from .gitmodules file (GITMODULES=path)
	@if [ -z "$(GITMODULES)" ]; then \
		echo "Usage: make import-services GITMODULES=/path/to/.gitmodules"; \
		exit 1; \
	fi
	@python3 scripts/import-gitmodules.py $(GITMODULES)

.PHONY: list-services
list-services: ## List configured services
	@python3 scripts/list-services.py

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
	echo "✅ Artifacts initialized: $$ARTIFACT_DIR"

.PHONY: validate
validate: ## Validate artifact completeness (TICKET=KEY)
	@if [ -z "$(TICKET)" ]; then echo "Usage: make validate TICKET=PROJ-1234"; exit 1; fi
	@LATEST=$$(ls -td $(ARTIFACTS_DIR)/$(TICKET)/*/ 2>/dev/null | head -1); \
	if [ -z "$$LATEST" ]; then echo "ERROR: No artifacts found for $(TICKET)"; exit 1; fi; \
	echo "Validating: $$LATEST"; \
	MISSING=0; \
	for f in ticket.md investigation.md plan.md changes.md test-results.md; do \
		if [ ! -f "$$LATEST/$$f" ]; then \
			echo "  ❌ Missing: $$f"; MISSING=$$((MISSING+1)); \
		elif ! grep -qv '<!--' "$$LATEST/$$f" 2>/dev/null; then \
			echo "  ⚠️  Empty: $$f"; \
		else \
			echo "  ✅ $$f"; \
		fi; \
	done; \
	if [ $$MISSING -gt 0 ]; then echo ""; echo "$$MISSING file(s) missing."; exit 1; fi; \
	echo ""; echo "✅ All artifacts present."

# =============================================================================
# SUBMODULE TRACKING
# =============================================================================

.PHONY: snapshot
snapshot: ## Capture submodule state (TICKET=KEY for file, or stdout)
	@python3 -c "\
	import json, subprocess, os; \
	result = subprocess.run(['git', 'submodule', 'status'], capture_output=True, text=True); \
	subs = {}; \
	for line in result.stdout.strip().split('\n'): \
		if line.strip(): \
			parts = line.strip().split(); \
			sha = parts[0].lstrip('+').lstrip('-'); \
			path = parts[1]; \
			subs[os.path.basename(path)] = {'sha': sha, 'path': path}; \
	output = json.dumps(subs, indent=2); \
	ticket = '$(TICKET)'; \
	if ticket: \
		import glob; \
		dirs = sorted(glob.glob(f'$(ARTIFACTS_DIR)/{ticket}/*/'), reverse=True); \
		if dirs: \
			fpath = os.path.join(dirs[0], 'submodules-before.json'); \
			open(fpath, 'w').write(output); \
			print(f'Saved to: {fpath}'); \
		else: print(output); \
	else: print(output)"

.PHONY: snapshot-after
snapshot-after: ## Capture post-change submodule state (TICKET=KEY)
	@if [ -z "$(TICKET)" ]; then echo "Usage: make snapshot-after TICKET=PROJ-1234"; exit 1; fi
	@python3 -c "\
	import json, subprocess, os, glob; \
	result = subprocess.run(['git', 'submodule', 'status'], capture_output=True, text=True); \
	subs = {}; \
	for line in result.stdout.strip().split('\n'): \
		if line.strip(): \
			parts = line.strip().split(); \
			sha = parts[0].lstrip('+').lstrip('-'); \
			path = parts[1]; \
			subs[os.path.basename(path)] = {'sha': sha, 'path': path}; \
	dirs = sorted(glob.glob(f'$(ARTIFACTS_DIR)/$(TICKET)/*/'), reverse=True); \
	if dirs: \
		fpath = os.path.join(dirs[0], 'submodules-after.json'); \
		open(fpath, 'w').write(json.dumps(subs, indent=2)); \
		print(f'Saved to: {fpath}'); \
	else: print('ERROR: No artifact directory found for $(TICKET)')"

.PHONY: diff
diff: ## Show submodule changes for a ticket (TICKET=KEY)
	@if [ -z "$(TICKET)" ]; then echo "Usage: make diff TICKET=PROJ-1234"; exit 1; fi
	@python3 scripts/submodule-diff.py $(ARTIFACTS_DIR)/$(TICKET)

# =============================================================================
# ENVIRONMENT
# =============================================================================

.PHONY: env-check
env-check: ## Verify environment health
	@echo ">>> Environment Health Check ($(ENV_FORMULA))"
	@$(MAKE) _env-check-$(ENV_FORMULA)

_env-check-kubernetes:
	@echo "--- Cluster ---"
	@kubectl cluster-info --request-timeout=5s 2>&1 | head -2
	@echo ""
	@echo "--- Pods ---"
	@kubectl get pods -A --no-headers 2>/dev/null | awk '{ \
		split($$3, ready, "/"); \
		if (ready[1] != ready[2] && $$4 != "Completed") \
			print "  ⚠️  " $$2 " (" $$1 "): " $$4 " " $$3; \
	}' || echo "  All pods healthy"
	@echo ""
	@echo "--- Services ---"
	@python3 -c "\
	import yaml; \
	cfg = yaml.safe_load(open('$(WORKSPACE_CONFIG)')); \
	for svc in cfg.get('services', []): \
		ns = svc.get('namespace', 'default'); \
		print(f'  {svc[\"name\"]}: namespace={ns}')" 2>/dev/null || true

_env-check-docker-compose:
	@echo "--- Docker ---"
	@docker info --format '{{.ServerVersion}}' 2>/dev/null && echo "  Docker running" || echo "  ❌ Docker not running"
	@echo ""
	@echo "--- Containers ---"
	@docker compose ps 2>/dev/null || echo "  No compose project found"

_env-check-custom:
	@echo "Running custom health check..."
	@python3 -c "\
	import yaml, subprocess; \
	cfg = yaml.safe_load(open('$(WORKSPACE_CONFIG)')); \
	cmd = cfg.get('environment', {}).get('commands', {}).get('health', ''); \
	if cmd: subprocess.run(cmd, shell=True); \
	else: print('No health command configured in workspace.yaml')"

# =============================================================================
# TESTING
# =============================================================================

TESTS_DIR := tests

.PHONY: test-smoke
test-smoke: ## Health endpoint checks (<30s)
	@echo ">>> Smoke Tests"
	@cd $(TESTS_DIR) && python -m pytest smoke/ -v -m smoke --timeout=30

.PHONY: test-api
test-api: ## API endpoint integration tests
	@echo ">>> API Tests"
	@cd $(TESTS_DIR) && python -m pytest api/ -v -m api --timeout=60

.PHONY: test-browser
test-browser: ## Browser/UI tests (Playwright)
	@echo ">>> Browser Tests"
	@cd $(TESTS_DIR) && python -m pytest browser/ -v -m browser --timeout=120

.PHONY: test-contract
test-contract: ## Cross-service API contract tests
	@echo ">>> Contract Tests"
	@cd $(TESTS_DIR) && python -m pytest contract/ -v -m contract --timeout=60

.PHONY: test-e2e
test-e2e: ## End-to-end workflow tests
	@echo ">>> E2E Tests"
	@cd $(TESTS_DIR) && python -m pytest e2e/ -v -m e2e --timeout=120

.PHONY: test-security
test-security: ## Security tests (auth, injection, access control)
	@echo ">>> Security Tests"
	@cd $(TESTS_DIR) && python -m pytest security/ -v -m security --timeout=60

.PHONY: test-quick
test-quick: test-smoke ## Alias for test-smoke (fast sanity check)

.PHONY: test-full
test-full: ## Run all test suites
	@echo ">>> Full Test Suite"
	@cd $(TESTS_DIR) && python -m pytest -v --timeout=120

# =============================================================================
# SERVICE OPERATIONS (thin wrappers — agent handles complex logic via skills)
# =============================================================================

.PHONY: logs
logs: ## Show service logs (SVC=name)
	@if [ -z "$(SVC)" ]; then echo "Usage: make logs SVC=backend-api"; exit 1; fi
	@$(MAKE) _logs-$(ENV_FORMULA) SVC=$(SVC)

_logs-kubernetes:
	@NS=$$(python3 -c "import yaml; cfg=yaml.safe_load(open('$(WORKSPACE_CONFIG)')); [print(s.get('namespace','default')) for s in cfg.get('services',[]) if s['name']=='$(SVC)']" 2>/dev/null || echo "default"); \
	kubectl logs -n $$NS -l app=$(SVC) --tail=100

_logs-docker-compose:
	@docker compose logs $(SVC) --tail=100

.PHONY: restart
restart: ## Restart a service (SVC=name)
	@if [ -z "$(SVC)" ]; then echo "Usage: make restart SVC=backend-api"; exit 1; fi
	@$(MAKE) _restart-$(ENV_FORMULA) SVC=$(SVC)

_restart-kubernetes:
	@NS=$$(python3 -c "import yaml; cfg=yaml.safe_load(open('$(WORKSPACE_CONFIG)')); [print(s.get('namespace','default')) for s in cfg.get('services',[]) if s['name']=='$(SVC)']" 2>/dev/null || echo "default"); \
	kubectl rollout restart deployment/$(SVC) -n $$NS

_restart-docker-compose:
	@docker compose restart $(SVC)

.PHONY: status
status: ## Show service status
	@$(MAKE) _status-$(ENV_FORMULA)

_status-kubernetes:
	@python3 scripts/service-status.py kubernetes

_status-docker-compose:
	@docker compose ps

# =============================================================================
# MCP DISCOVERY
# =============================================================================

.PHONY: discover-mcp
discover-mcp: ## Auto-detect MCP servers and generate config
	@echo ">>> MCP Discovery"
	@echo "This skill runs inside the AI agent context."
	@echo "Ask the agent: 'discover available MCP tools'"
	@echo "Or invoke the discover-mcp skill directly."
	@mkdir -p $(GENERATED_DIR)

# =============================================================================
# UTILITIES
# =============================================================================

.PHONY: clean-artifacts
clean-artifacts: ## Remove all artifacts (CAUTION)
	@echo "This will delete ALL artifacts. Are you sure? [y/N]"
	@read -r confirm; if [ "$$confirm" = "y" ]; then rm -rf $(ARTIFACTS_DIR)/*; echo "✅ Cleaned"; else echo "Cancelled"; fi

.PHONY: workspace-info
workspace-info: ## Show workspace configuration summary
	@python3 scripts/workspace-info.py

# =============================================================================
# DOCUMENTATION (agent-driven — these targets provide entry points)
# =============================================================================

.PHONY: understand
understand: ## Map services and generate documentation (agent skill)
	@echo ">>> Workspace Understanding"
	@echo "This skill runs inside the AI agent context."
	@echo "Ask the agent: 'understand the workspace' or 'map the services'"
	@echo ""
	@echo "The agent will:"
	@echo "  1. Scan all services under services/"
	@echo "  2. Map inter-service communication"
	@echo "  3. Generate docs/ (service-map, api-contracts, infrastructure, env-vars, conventions)"
	@mkdir -p $(DOCS_DIR)

.PHONY: generate-docs
generate-docs: ## Generate workspace documentation (agent skill)
	@echo ">>> Documentation Generation"
	@echo "This skill runs inside the AI agent context."
	@echo "Ask the agent: 'generate documentation' or 'document the architecture'"
	@mkdir -p $(DOCS_DIR)
