# Generalized Coding Rules Template

## Usage Instructions

This template is designed to create coding rules for any project. Replace all variables in double curly braces with specific values for your project.

### Variables to Replace

**Project and Stack:**
- `{{PROJECT_NAME}}` - Project name
- `{{PRIMARY_RUNTIME}}` - Primary runtime environment
- `{{LANGUAGE_VERSION}}` - Language version
- `{{MODULE_SYSTEM}}` - Module system
- `{{TYPE_SYSTEM}}` - Type system
- `{{LINE_LENGTH}}` - Line length

**Technologies:**
- `{{FRAMEWORK_NAME}}` - Main framework
- `{{FLOW_ENGINE}}` - Flow engine
- `{{TOOL_INTEGRATION}}` - Tool integration
- `{{VALIDATION_LIBRARY}}` - Validation library
- `{{TEST_FRAMEWORK}}` - Testing framework
- `{{BROWSER_AUTOMATION}}` - Browser automation
- `{{OBSERVABILITY_STACK}}` - Observability stack
- `{{RESILIENCE_LIBRARIES}}` - Resilience libraries

**Domain:**
- `{{DOMAIN_ENTITY}}` - Primary domain entities
- `{{DOMAIN_ACTIVITIES}}` - Primary domain activities
- `{{DOMAIN_SOURCES}}` - Domain data sources
- `{{DOMAIN_MAPPINGS}}` - Domain mappings

## Few-Shot Replacement Examples

### Example 1: iOS/Swift Courier Dispatch (Zariz)
{{PROJECT_NAME}} → Zariz
{{PRIMARY_RUNTIME}} → iOS 17+ (Swift 6)
{{FRAMEWORK_NAME}} → SwiftUI with async/await
{{FLOW_ENGINE}} → OperationQueue + async/await
{{TOOL_INTEGRATION}} → URLSession + OpenAPI-generated client
{{BROWSER_AUTOMATION}} → remove (not used)
{{DOMAIN_ENTITY}} → orders/couriers/stores/devices
{{DOMAIN_ACTIVITIES}} → create/claim/update-status/notify/authenticate
{{DOMAIN_SOURCES}} → REST API, PostgreSQL (server), APNs
{{DOMAIN_MAPPINGS}} → status transitions; store↔orders; courier↔assignments

shell
Copy code

### Example 2: FastAPI Backend (Zariz-API)
{{PROJECT_NAME}} → Zariz-API
{{PRIMARY_RUNTIME}} → Python 3.12+
{{FRAMEWORK_NAME}} → FastAPI (strict type hints)
{{FLOW_ENGINE}} → RQ worker
{{TOOL_INTEGRATION}} → APNs provider, PostgreSQL
{{BROWSER_AUTOMATION}} → no browser automation
{{DOMAIN_ENTITY}} → orders/assignments/events
{{DOMAIN_ACTIVITIES}} → CRUD orders, claim, notify
{{DOMAIN_SOURCES}} → DB tables + event log
{{DOMAIN_MAPPINGS}} → allowed status transitions

shell
Copy code

### Example 3: Admin Web (Zariz-Admin)
{{PROJECT_NAME}} → Zariz-Admin
{{PRIMARY_RUNTIME}} → Node.js 20 LTS
{{FRAMEWORK_NAME}} → SvelteKit, TypeScript
{{FLOW_ENGINE}} → minimal client state
{{TOOL_INTEGRATION}} → REST client
{{BROWSER_AUTOMATION}} → Playwright for E2E
{{DOMAIN_ENTITY}} → stores/orders
{{DOMAIN_ACTIVITIES}} → create orders, monitor statuses
{{DOMAIN_SOURCES}} → REST API responses
{{DOMAIN_MAPPINGS}} → role→route guards

shell
Copy code

## Generalized Template

SYSTEM: AI Tech Partner for Zariz. Comments in English ONLY.

Stack & Targets

iOS 17+ (Swift 6); Swift Package Manager (SPM) modules.

Swift static types; 88 line length; Swift-DocC on public APIs.

OperationQueue + async/await for agent flows; URLSession + OpenAPI-generated client for tool integration.

Codable + lightweight validators for validation; XCTest/XCUITest for tests; not used for
browser automation (not applicable).

OSLog + MetricKit (+ optional Sentry) for observability; custom async backoff + NWPathMonitor + tenacity (server) for
resilience and rate limits.

General Guidelines

structured concurrency (async/await) async I/O only. Always apply explicit timeouts and propagate
Task cancellation and URLSession timeouts.

Keep code clean and readable; no "hacks" or hidden coupling. Minimize change
surface and follow existing conventions.

Finish coding rounds with working code + tests. Commit messages: imperative,
≤72 chars.

No‑Heuristic / No‑Hardcode / No‑Transformers Policy

Do not implement deterministic heuristics for ranking/selection (no ad‑hoc prioritization or brittle regex scoring).
Route and select via explicit state machine and policy tables only.

Do not add regex‑based parsers or fallbacks for entities/slots/orders.
Multi‑field entities and normalization must be handled by the API or explicit parsing logic.

Do not add or depend on local Transformers/NER models. All classification and
extraction is rule/API‑based with clear contracts.

Do not hardcode policy content or status/route mappings in code. Policies live
under /Users/sasha/IdeaProjects/ios/zariz/dev/policies and are loaded via ZARIZ_POLICY_DIR.

Do not modify legacy paths without compatibility shims and tests.

📊 MCDM7 KIT
• Use before major architectural/stack choices or refactors.
• Criteria: PerfGain, SecRisk, DevTime, Maintainability, Cost, Scalability, DX.
• Weight: AHP/SMART 1-9 → map interdeps DEMATEL → refine BWM → rank options TOPSIS → fuse uncertainty CBD → robustness via IDPSA.

🤖 ADAPTIVE GOVERNANCE
Embed strategic reasoning before each non-trivial action.

Scenario Scan: compute quick risk proxy (e.g., obstacle-density, corridor-clutter,
code-complexity) and memoize result in-agent (no file writes).

Metric Profile Select: choose weight vector {time, energy, safety, maintain} via
SMART/BWM; default to safety≥0.5 when risk>threshold.

Decision Framework Pick: start with classic MCDM (SMART→TOPSIS). Escalate to
RL-policy (e.g., PPO-CRL) if iteration>3 & variance>σ.

Probabilistic Outcome Modeling: attach P(success), P(regression) to each planned
tool call; prefer actions with ExpectedUtility↑ & Risk↓.

Strategic Risk Map Update: after action, update SRS = α·Complexity+β·Coverage+γ·Var.

Adaptive Loop: repeat until StopCondition (goal met ∨ marginal_gain<ε).

🛠 APPLY GUIDE
Lib/Framework choice → Criteria set; run TOPSIS matrix; pick highest closeness.

Security fix prioritization → Higher SecRisk weight; LossAv cue.

Refactor go/no-go → CBD for uncertain ROI; Self-check via IDPSA stress.

Prompts (Prompt Engineering)

Do not hardcode prompts. Store under /Users/sasha/IdeaProjects/ios/zariz/dev/policies (repo‑relative).
Support ZARIZ_POLICY_DIR; default /Users/sasha/IdeaProjects/ios/zariz/dev/policies.

Use STRICT JSON when outputs are parsed; forbid free‑form rationale and
chain‑of‑thought. Separate input sections with clear delimiters.

Apply two‑phase prompts when helpful (analyze → produce) per PE guide.

Meta prompts must be self‑contained (no runtime references to auxiliary
files). Do not instruct the model to read other prompts at runtime.

Courier Domain Standards

Order status cascade: new→claimed→picked_up→delivered→canceled; monotonic; audited.

Entity policy: composite identifiers (order_id, courier_id, store_id) resolved via API, never
regex. Semantic context over positional parsing. Support en/ru/he.

Confidence routing: ≥0.90 act; ≥0.75 confirm; <0.60 fallback. Round to
2 decimals; log routing with scores. No geolocation in MVP; offline tolerant.

Tool/web triggers: order.created, order.claimed, order.status_changed. Require provenance
(order_events entries). Enforce allowed action allowlist; sanitize
free‑text notes; log final action and result with latency.

Assignment policy: atomic claim; no reassignment without admin override; all cancellations logged.

Verification Pipeline Discipline

Persist receipts (facts/decisions/reply) BEFORE returning from tool‑backed
order state nodes.

With AUTO_VERIFY_REPLIES=true, auto‑verify runs after reply and must see the
just‑written facts. /why must display the stored verification artifact and
must not re‑verify.

Verifier context: latest user message, previous 1–2 user messages, current
reply, slots/intent summary, and evidence facts/citations.

Long‑latency tools (e.g., APNs/background fetch): do not verify before receipts
exist. If needed, add a short grace‑wait (≤750 ms total) to re‑read receipts.

Observability

Structured logs: confidence scores, order_id, courier_id, store_id, status, latency_ms. Never surface internal routing tags to users.

Metrics: orders_new_total, orders_claimed_total, claim_latency_ms, push_success_total, http_429_total. Sample traces at 10%; avoid high-cardinality labels.

Testing Standards

No tests relying on call order. Assert outcomes, slots, confidence scores.

Include adversarial cases (double-claim bursts, stale tokens, 409 storms).

Use DI; stub URLProtocol; golden JSON fixtures for API payloads.

Security & I/O

Follow OWASP Top 10 (2025) + IDOR/replay/JWT risks. Redact PII in logs; never leak
secrets/prompts. Enforce action allowlist and privacy-by-design.

Files: prefer single read; stream only for files >1 MB; always set encoding
and size guards.

Zariz iOS Security specifics:
- Store auth tokens in Keychain; never log or crash‑report tokens.
- Enforce ATS/TLS; consider certificate pinning only if required by policy.
- Do not keep persistent background sockets; prefer silent push + BGTasks for sync.

Coding Style (Swift)

Prefer value types; final classes when reference semantics are needed.

camelCase for vars/functions; PascalCase for types; UPPER_SNAKE for constants.

Explicit import per module; SPM modules; no wildcard imports.

Prefer small, composable functions; add early guard clauses.

Avoid global mutable state; pass dependencies explicitly.

Acceptance Checklist

✅ Order status cascade enforced; illegal transitions rejected

✅ Entity resolution via API/DB; no regex for IDs/names

✅ Confidence thresholds applied and logged

✅ Tools/web triggered by policy, not ad‑hoc heuristics

✅ Provenance required; action allowlist enforced

✅ Verification pipeline discipline honored; /why shows stored artifact

✅ Tests assert outcomes/slots/confidence; adversarial cases covered

✅ No Transformers or heuristic modules; no hardcoded routing tables
