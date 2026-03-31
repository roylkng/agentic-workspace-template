# Skill: Workspace Understand

> Map all services, their interactions, APIs, infrastructure, and conventions.
>
> **Trigger**: "understand the workspace", "map the services", auto-invoked after onboarding.
> **Output**: `docs/service-map.md`, `docs/api-contracts.md`, `docs/infrastructure.md`, `docs/env-vars.md`, `docs/conventions.md`

---

## Step 1: Inventory Services

### 1a. Read workspace.yaml

Get service list: name, path, language, port, namespace. If `services` is empty, scan `services/` directly.

### 1b. Verify each service

```bash
ls services/*/
test -d services/<name>/.git || test -f services/<name>/.git
```

### 1c. Detect language and framework

Check files in order — first match wins:

| File | Language | Framework |
|------|----------|-----------|
| `pyproject.toml` with `fastapi` | Python | FastAPI |
| `pyproject.toml` with `django` | Python | Django |
| `pyproject.toml` with `flask` | Python | Flask |
| `pyproject.toml` | Python | Poetry |
| `requirements.txt` | Python | pip |
| `package.json` with `next` | Node.js | Next.js |
| `package.json` with `react` | Node.js | React |
| `package.json` with `express` | Node.js | Express |
| `package.json` | Node.js | Generic |
| `go.mod` | Go | Go module |
| `Cargo.toml` | Rust | Cargo |
| `pom.xml` | Java | Maven |
| `build.gradle(.kts)` | Java/Kotlin | Gradle |
| `*.csproj` / `*.sln` | C# | .NET |

### 1d. Find entrypoint

| Framework | Entrypoints |
|-----------|------------|
| FastAPI | `main.py`, `app.py`, `app/main.py`, grep `FastAPI()` |
| Express | `index.js`, `app.js`, `server.js`, `"main"` in package.json |
| Django | `manage.py`, `wsgi.py`, `asgi.py` |
| Go | `main.go`, `cmd/*/main.go` |
| Spring Boot | `@SpringBootApplication` class |
| Next.js | `pages/` or `app/` directory |
| Rust | `src/main.rs` |

→ Start building `docs/service-map.md` § Service Inventory.

---

## Step 2: Discover API Surface

### Route detection by framework

| Framework | Grep Pattern |
|-----------|-------------|
| FastAPI | `@app.get\|@app.post\|@app.put\|@app.delete\|@router.` |
| Express | `router.get\|router.post\|app.use` |
| Django | `path(\|re_path(` in `urls.py` |
| Go | `http.HandleFunc\|mux.Handle\|r.GET\|r.POST` |
| Spring | `@GetMapping\|@PostMapping\|@RequestMapping` |
| Next.js | Files in `pages/api/` or `app/api/` |

### Per endpoint, extract

1. **Method + path** (e.g., `POST /api/v1/chat`)
2. **Request shape** — body parsing, Pydantic models, struct tags
3. **Response shape** — return statements, serialization
4. **Auth** — middleware, decorators, `@PreAuthorize`
5. **Who calls it** — discovered in Step 3

→ `docs/api-contracts.md`

---

## Step 3: Map Inter-Service Communication

### 3a. HTTP Client Calls

| Language | Grep Pattern |
|----------|-------------|
| Python | `requests\.\(get\|post\)\|httpx\.\|aiohttp\.\|ClientSession` |
| Node.js | `fetch(\|axios\.\|got(\|http\.request` |
| Go | `http\.Get\|http\.Post\|http\.NewRequest` |
| Java | `RestTemplate\|WebClient\|@FeignClient` |

For each call: what URL? Hardcoded or from config? Match target to a route from Step 2.

```bash
grep -rn "SERVICE.*URL\|SERVICE.*HOST\|localhost:[0-9]" services/<svc>/src/
```

### 3b. Message Queues

| Library | Grep Pattern |
|---------|-------------|
| RabbitMQ (Python) | `pika\.\|aio_pika\.\|channel\.basic_publish` |
| RabbitMQ (Node) | `amqplib\|channel\.sendToQueue\|channel\.assertQueue` |
| Kafka | `KafkaProducer\|KafkaConsumer\|\.produce(\|\.subscribe(` |
| Redis pub/sub | `\.publish(\|\.subscribe(\|pubsub` |

For each: producer or consumer? Queue/topic name? Data shape? Find the other end in other services.

### 3c. Shared Database

```bash
grep -rn "DATABASE_URL\|SQLALCHEMY_DATABASE\|MONGO.*URI\|REDIS.*URL" services/<svc>/src/
```

If two services share a DB: do they access the same tables? Who owns vs reads?

### 3d. gRPC

```bash
find services/<svc>/ -name "*.proto"
grep -rn "pb2\|_grpc\|grpc\.\(Server\|Channel\)" services/<svc>/src/
```

→ `docs/service-map.md` § Inter-Service Communication

---

## Step 4: Map Infrastructure

```bash
# Databases & caches
grep -rn "DATABASE_URL\|DB_HOST\|MONGO.*URI\|REDIS.*URL\|QDRANT.*URL" services/*/src/

# Auth providers
grep -rn "KEYCLOAK\|AUTH0\|OAUTH\|JWT.*SECRET\|COGNITO" services/*/src/

# External APIs
grep -rn "OPENAI\|ANTHROPIC\|STRIPE\|SENDGRID\|AWS_\|AZURE_\|GCP_" services/*/src/

# K8s/Docker
find services/ -name "values.yaml" -path "*/helm/*"
find . -name "docker-compose*.yml" -maxdepth 2
```

→ `docs/infrastructure.md`

---

## Step 5: Map Environment Variables

### Find all env var reads

| Language | Grep Pattern |
|----------|-------------|
| Python | `os\.environ\|os\.getenv` |
| Node.js | `process\.env\.` |
| Go | `os\.Getenv` |
| Java/Spring | `@Value\|Environment\.` |

Also: `find services/ -name ".env*" -not -path "*node_modules*"`

### Categorize

| Category | Signal |
|----------|--------|
| Cross-service | `SERVICE.*URL`, `SERVICE.*HOST` — points to another service |
| Infrastructure | DB URLs, queue connections |
| Secrets | Passwords, tokens, API keys |
| External | Third-party credentials (`OPENAI_API_KEY`) |
| Service config | Ports, feature flags, log levels |

→ `docs/env-vars.md`

---

## Step 6: Identify Conventions

Read code to identify patterns:

- **Auth flow**: Token creation, validation, format, passing mechanism
- **Error handling**: Error response shape, status code usage, propagation
- **Logging**: Library, format (structured/unstructured), correlation IDs
- **Testing**: `find services/<svc>/ -name "test_*" -o -name "*.test.*" -o -name "*.spec.*" | head -20`
- **CI/CD**: `find services/<svc>/ -name "*.yml" -path "*/.github/workflows/*"`

→ `docs/conventions.md`

---

## Step 7: Generate Dependency Graph

Build Mermaid diagram from Step 3 connections:

- Node labels: `name["Display<br/>Framework :port"]`
- Edge labels: `-->|protocol| target`
- Shapes: `[]` services, `[()]` databases/queues

→ `docs/service-map.md` § Dependency Graph

---

## Step 8: Write Documentation

Generate files under `docs/` using templates at `.github/templates/docs/`.

**Rules:**
- Only document what you verified in code. Mark uncertain items with "(?)"
- No empty sections — write "None detected" if nothing found
- Service names must match `workspace.yaml`
- Endpoint paths must be exact (copy from code)

---

## Step 9: Present Summary

```
## Workspace Understanding Complete

Services: X | Endpoints: Y | Connections: N | Env vars: M (K shared)

Generated: service-map.md, api-contracts.md, infrastructure.md, env-vars.md, conventions.md
```

---

## Incremental Updates

When re-invoked: read existing `docs/`, only deep-scan new/changed services (check git status), merge findings.

## Troubleshooting

| Problem | Solution |
|---------|---------|
| No recognizable framework | Read entrypoint + README manually |
| Can't find inter-service connections | Check Docker/K8s configs for network topology |
| Too many env vars | Focus on cross-service and infrastructure vars first |
| Service >1000 files | Focus on routes, clients, config, tests dirs |
