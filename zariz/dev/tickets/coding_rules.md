iOS Coding Rules (2025 Edition)
Stack & Targets

Platform & Modules: Target iOS 17+ as the primary runtime; use Swift Package Manager (SPM) for modularization of code.

Language & Standards: Adopt Swift 6 (strict static type system). Follow Swift API Design Guidelines with documentation comments (DocC) on public APIs. Maintain a line length of ~100 characters for readability.

UI & Async Flows: Use SwiftUI-first for UI development (prefer SwiftUI over UIKit for new code). Leverage Swift’s structured concurrency (async/await and actors) for asynchronous flows. Integrate external services or AI tools via native networking (e.g., URLSession or official SDKs) rather than custom sockets.

Data & Testing: Use SwiftData for local persistence in new code (favor it over legacy Core Data when targeting iOS 17+). Utilize built-in data handling (e.g., Swift’s Codable for JSON). Write tests with XCTest for unit, integration, and UI coverage. (Browser automation is not applicable on iOS.)

Observability & Resilience: Use Apple’s unified logging and metrics systems: OSLog (with subsystems/categories and privacy markers) for logs, and MetricKit for performance and crash metrics. Implement resilience with lightweight patterns (e.g., exponential backoff and retry for network calls) instead of introducing heavy third-party frameworks.

General Guidelines

Async by Default: Perform all I/O and long-running tasks with asynchronous patterns (Swift structured concurrency). Always use explicit timeouts and propagate cancellation to avoid hanging tasks.

Clean & Conventional Code: Keep code clean, readable, and well-organized. Avoid "hacks," magic numbers, or hidden couplings. Minimize the change footprint by extending existing patterns and following established naming and style conventions.

Done Means Tested: Finish each coding round with working code and accompanying tests. Aim for small, frequent commits with clear, imperative messages (≤ 72 characters) describing the change.

Architecture & Separation: Embrace Clean Architecture principles. Separate UI, business logic, and data layers. For SwiftUI apps, use an MVVM structure or adopt The Composable Architecture (TCA) for state management. This ensures views are lightweight and logic is testable. Each module or component should have a single responsibility and clear interface.

Performance & Safety: Write efficient code mindful of performance. Avoid blocking the main thread — use background threads or tasks for expensive work and use Instruments to catch slow routines or memory issues. Prioritize safety in code: avoid force-unwrapping optionals, handle errors and edge cases, and validate inputs. Prefer safe APIs and memory-managed constructs to prevent crashes or undefined behavior.

Observability & Modular Design: Build observability into features (e.g., log important user actions, measure critical path timings) while respecting privacy. Strive for modular design: break features into frameworks or packages with well-defined APIs. This modularity improves maintainability, testability, and enables parallel development.

No‑Heuristic / No‑Hardcode / No‑Transformers Policy

No Magic Heuristics: Do not implement ad-hoc deterministic algorithms or ranking heuristics for decisions that should be learned or data-driven (no custom scoring rules or hardcoded decision trees – {{FORBIDDEN_HEURISTICS}}). Use the designated routing or policy method (e.g., an ML model or rules engine: {{ROUTING_METHOD}}) for such decisions.

No Regex Parsing for NLP: Avoid regex-based parsers or brittle string matching for extracting domain entities (e.g., {{DOMAIN_ENTITY}}) or user intents. Multi-token extraction, entity resolution, and input normalization must be handled by the AI/NLP system or a robust parsing library, not via regex hacks.

No Local ML Models: Do not embed local Transformer/LLM models or standalone NER classifiers in the app. All classification, NLP, or complex decision logic should rely on the approved AI services or tools with clear contracts. (This prevents divergence in behavior and large binary sizes.)

No Hardcoded Prompts or Policies: Do not hardcode prompt text, responses, or domain-specific mappings ({{DOMAIN_MAPPINGS}}) in code. Store such data in configuration or resource files under {{PROMPT_DIR}}, and load them via environment or configuration variables (e.g., {{PROMPT_ENV_VAR}}). This allows updates without code changes and eases localization and tuning.

Deprecate Legacy Approaches: Remove or avoid any legacy policy code that conflicts with these rules ({{LEGACY_POLICY}}). The codebase should not contain obsolete workaround logic once modern patterns are in place.

📊 MCDM7 KIT

Use this multi-criteria decision-making framework to guide major technical choices or refactoring plans:

Criteria to Consider: Evaluate options based on Performance Gain, Security Risk, Development Time, Maintainability, Cost, Scalability, and Developer Experience (DX).

Weighted Scoring: Assign weights to criteria using AHP/SMART (scale 1–9). Map out interdependencies with DEMATEL, refine weights via BWM, then rank options using TOPSIS. Account for uncertainty by introducing confidence intervals (CBD) and test robustness of the decision via Interval DPSA.

Apply Quantitatively: Before committing to a major change (adopting a new library, architecture shift, etc.), run this quantitative analysis. Favor the option with the highest composite score (especially if it shows clear wins in performance/security) to ensure data-driven decision making.

🤖 ADAPTIVE GOVERNANCE

Embed a strategic, looped decision process within development for non-trivial actions:

Scenario Scan: Quickly assess the current scenario for risk factors and complexity (e.g., new feature touches sensitive data? Large refactor in critical module?). Determine a rough risk level and note any high-risk elements. (This is a lightweight mental check, no persistent log.)

Metric Profile Select: Based on the scenario, choose a weighting for time vs. energy (effort) vs. safety vs. maintainability. For example, if the risk is high, put ≥50% weight on safety. Use simple methods like SMART or BWM to set these weights explicitly.

Decision Framework Pick: Start with a straightforward decision framework (e.g., the MCDM7 criteria above). If the decision space is complex or if a simple approach fails after a few iterations (≥3) or shows high outcome variance, escalate to a more adaptive approach (for instance, consider reinforcement learning policy or simulation to evaluate options).

Probabilistic Outcome Modeling: Estimate outcomes for each action. For each possible decision, attach a probability of success vs. failure/regression. Prefer actions that maximize expected utility (high success probability * high benefit) while keeping risk low.

Strategic Risk Map Update: After executing an action, update a "risk map" score for the project (e.g., combine factors like code complexity, test coverage, recent bug frequency). This quantifies the changing risk profile as modifications are made.

Adaptive Loop: Repeat the above steps iteratively until the goal is met or improvements become marginal (change < ε). Continuously adapting in this way ensures responsiveness to new information and incremental changes.

🛠 APPLY GUIDE

Library/Framework Choices: When adding a new library or framework, clearly define evaluation criteria and use a decision matrix (as in MCDM7) to compare alternatives. Choose the option with the best balance of performance, community support, security, and long-term maintainability (the highest “closeness” score in TOPSIS).

Security Fixes: For security-related decisions or patches, weigh security risk more heavily. Apply a conservative bias (loss aversion) — prioritize fixes that eliminate high-severity vulnerabilities first, even if the reward (feature gain) is low.

Refactor Go/No-Go: Before large refactors, use outcome modeling to estimate benefits (e.g., speed, clarity) versus risks (bugs, delays). If uncertainty is high, do a small proof-of-concept or use scenario analysis. Only proceed with refactoring if the expected benefits outweigh risks by a comfortable margin, and have a rollback plan.

Prompts (Prompt Engineering)

No Inline Prompts: Do not embed prompt strings directly in code. Store prompts in external files under the prompt directory (e.g., Prompts/) and reference them via configuration. Support loading prompt overrides via an environment variable (PROMPT_PATH or similar) so they can be updated without code changes.

Structured Output for Parsing: When an AI’s output will be consumed by the app (parsed), enforce a strict format like JSON. Do not allow the model to return free-form text for machine-critical outputs. Also, instruct the model to exclude any reasoning or extraneous content (no chain-of-thought in outputs). Clearly delimit sections if the prompt requires multiple parts.

Two-Phase Prompting: If appropriate, use a two-step prompt approach (e.g., first ask the model to analyze or extract info, then in a second prompt have it produce the final result). This can improve reliability of complex tasks. However, ensure the final user-facing response is direct and succinct—any reasoning phase should not leak to the user.

Self-Contained Prompts: Prompts should include all necessary context. Do not rely on the model retrieving or reading external files at runtime beyond the given prompt input. (No instructions like “refer to the previous prompt file” at runtime.) This ensures reproducibility and avoids runtime errors if external context is unavailable.

Domain-Specific Standards

(This section is reserved for project-specific standards and policies. Define domain-specific cascade patterns, entity handling rules, allowlists/blocklists for content or APIs, and any custom policy rules here. For example, if the app has a particular workflow or compliance requirement, detail those standards in this section.)

Verification Pipeline Discipline

Persist Before Reply: Persist key artifacts (evidence retrieved, decisions made, final answers) before returning a response to the user for any AI-assisted or tool-driven features. This ensures that there is a record of what the app did (or what the AI responded) that can be audited or verified.

Automated Post-Verification: If AUTO_VERIFY_REPLIES=true, the system should automatically run a verification step immediately after generating a reply. This verifier should check the just-persisted artifacts. The user-facing debug command (e.g., a “why” or diagnostic output) should retrieve the stored verification results, and never trigger a fresh verification during inquiry (to guarantee consistency).

Verifier Context Window: Provide the verification logic with a concise but complete context. Typically include: the latest user query, the relevant recent interaction history (last 1-2 messages), the AI’s response, a summary of detected intent/slots, and any evidence or citations used. This helps the verifier assess the answer in context and catch omissions or errors.

Long-Latency Tool Handling: For any tools or API calls with long latency (e.g., calls that take several seconds), design the flow such that verification waits for tool results to be stored. If needed, implement a short delay (≤ 750ms) or an event trigger to ensure that by the time verification runs, all results are available. This prevents race conditions where verification might otherwise run on incomplete data.

Observability

Structured Logging: Use OSLog for structured logging with subsystem and category tags for different parts of the app. Include relevant metadata (like operation identifiers, user session IDs, confidence scores from AI responses, etc.) in log messages. Always mark sensitive information with .private or .sensitive so that it’s redacted in analytics and console output. Never expose internal implementation details or IDs to end users via logs.

Metrics & Monitoring: Leverage MetricKit to collect app performance and crash metrics automatically. Define custom metrics for critical user flows or performance goals (e.g., response time, cache hit rates) using OSLog intervals or signposts. Avoid high-cardinality metrics (don’t create a separate metric tag for unbounded values like user IDs or dynamic content). Integrate with monitoring dashboards if available to track these metrics over time. Ensure that any alerting on these metrics considers normal variability to reduce noise.

In-App Debugging: Include the ability (for development builds or via secret gesture) to display key debug info, such as current feature flags, build identifiers, or last sync time. This aids in observability during QA without exposing internal data in production.

Testing Standards

Deterministic Tests: Write tests that assert outcomes and state, not internal implementation or call order. Each test should reliably pass or fail based on deterministic conditions. For example, test the final output of a ViewModel given a mock input, rather than testing how many times a function was called internally.

Adversarial Cases: Include tests for edge cases and adversarial scenarios. For an AI feature, this means tests for prompt-injection strings, extremely long inputs, or malformed outputs from the AI. For general app features, test boundary conditions (empty data, maximum allowed data, network failures, etc.). These ensure the app handles unexpected situations gracefully.

Coverage of Components: Ensure unit tests cover models, view models, and any critical logic (e.g. data parsing, security-related functions). Write UI tests for important user flows (login, onboarding, primary features) using Xcode’s UI Testing framework to catch integration issues. Name test methods clearly (testFunctionality_description) and use Arrange-Act-Assert pattern within test bodies for clarity.

No Global State in Tests: Tests should be isolated. Avoid inter-test dependencies or reliance on global mutable state. Reset singletons or shared resources between tests, or better, refactor to inject dependencies so you can substitute fakes/stubs. This prevents flaky tests and makes the test suite reliable in continuous integration.

Continuous Testing: Run the full test suite on every pull request or build. Treat warnings in tests (and the code in general) as errors. Utilize static analysis and linters to catch issues early, and consider integrating tools for thread safety and memory leak detection (especially when using Swift concurrency).

Security & I/O

OWASP & Data Protection: Adhere to OWASP Top 10 (2025) security practices. Identify and mitigate any project-specific security risks (e.g., {{DOMAIN_SECURITY_RISKS}}). Always sanitize and validate inputs from any external source (network, file, user input) to prevent injection attacks. Redact PII (personally identifiable information) in logs and never expose sensitive info (like API keys, tokens, or prompts) in any user-facing context or analytics.

Secure Storage & Transmission: Store secrets, tokens, and sensitive data using the Keychain or Secure Enclave. Avoid storing any secrets in plaintext or in user defaults. Use short-lived tokens (e.g., JWTs with brief expiration) for authentication and refresh them regularly to limit damage from leaks. Enforce App Transport Security (ATS) – all network calls must use HTTPS/TLS with strong ciphers. Do not bypass ATS unless absolutely necessary, and never for development convenience.

Proper File I/O: When reading or writing files, prefer atomic operations (write to a temp file then rename) to avoid partial writes. For large files (>~1 MB), use streaming APIs or chunk processing to manage memory. Always specify character encodings (UTF-8 by default) when handling text and impose size limits on data read from external sources to avoid memory exhaustion or buffer overflow-like issues. Respect iOS sandbox rules and request user permissions for any file or photo access, only when needed.

Background Execution: Use BGTaskScheduler for scheduling background tasks and silent push notifications for server-initiated updates. Avoid long-running background processes or holding open network sockets for realtime updates—these drain battery and are restricted by the system. Instead, use background fetch or push mechanisms to handle updates while the app is not in the foreground. Design background tasks to be efficient and short, and test them thoroughly under real device conditions (limited CPU, etc.).

Apple Security Services: Prefer Apple-provided security frameworks and services for sensitive operations. For example, use CryptoKit for cryptography (instead of custom crypto), and use AuthenticationServices (Sign in with Apple, etc.) where applicable to offload security-sensitive flows. This ensures compliance with Apple’s security standards and reduces the chance of introducing vulnerabilities.

Coding Style (Swift 6 / iOS)

Language Preferences: Use modern Swift features and idioms. Prefer value types (structs, enums) for modeling data and use classes only when reference semantics are needed. Embrace optionals and Result types for error handling instead of using sentinel values. Follow the Swift API Design Guidelines for naming (lowerCamelCase for functions/properties, UpperCamelCase for types) and clarity. Document public APIs with Swift Markup (/** … */) comments so they can generate DocC documentation.

Framework & API Choices: Favor Apple’s modern frameworks in implementation. For example, build UI with SwiftUI instead of UIKit for new code; use SwiftData for persistence rather than directly using Core Data (only fall back to Core Data APIs for backward compatibility or advanced use cases not yet covered by SwiftData). Use Swift Charts for data visualization instead of custom drawing or third-party chart libraries. Leverage App Intents to expose app functionality to Siri and Shortcuts rather than older Intents UI frameworks. In general, stay up-to-date with Apple’s latest recommended APIs and deprecate legacy usage.

Function Design: Keep functions and methods concise and focused on a single task. Break down complex processes into smaller, reusable functions. Use guard statements early to exit on invalid conditions, which improves readability by reducing nesting. This yields code that is easier to test and less prone to errors.

Imports and Dependencies: Organize imports at the top of files and import only what is necessary. Avoid large monolithic files—split code into logical modules and extensions. Do not abuse @objc or Objective-C runtime features; prefer pure Swift implementations. When using packages, respect clear module boundaries and avoid cyclic dependencies. Each module/package should explicitly declare its public interface; internal details should not bleed into other modules.

State Management: Avoid global mutable state and singletons for shared data. Instead, pass dependencies through initializers or use environment objects (SwiftUI Environment) for things like settings that genuinely need to be global. In SwiftUI, utilize @State, @StateObject, @ObservedObject, and @EnvironmentObject appropriately to manage state in views, but avoid overly complex observable object graphs. Immutable data models (let constants) are preferred wherever possible to make reasoning about state easier.

Modern Language Features: Take advantage of Swift’s advanced features to reduce boilerplate and enhance clarity. Use Swift Macros (available in Swift 6) to generate repetitive code or configuration at compile time (for example, to auto-synthesize conformance or create DSLs). Utilize result builders (like SwiftUI’s @resultBuilder) to construct DSLs or complex hierarchies in a readable way. Prefer Swift concurrency over older paradigms — for instance, use async/await and AsyncSequence instead of Combine for new asynchronous code (Combine can be used for compatibility but is generally in maintenance mode). These modern features should be used judiciously to make code simpler and safer, not more obscure.

Acceptance Checklist

✅ Policy Adherence: All decision logic uses defined policies or ML-driven methods. No ad-hoc heuristics or hardcoded ranking rules are present in the final code.

✅ No Regex for NLP: No code uses regex or brittle string parsing for understanding user input or domain entities. All such parsing leverages the AI model or robust libraries, ensuring support for multi-word inputs and different languages.

✅ Confidence Thresholds: If the app makes AI-driven decisions based on confidence scores (e.g., whether to autonomously act or ask for confirmation), those thresholds (e.g., ≥0.90 auto-act, ≥0.75 need confirm) are applied and logged. The decision outcomes are traceable in logs for debugging.

✅ Tool Usage Governance: All external tool or web API calls are invoked through well-defined policies (no inline or unauthorized calls). Each integration has provenance requirements (e.g., the app records the source of information used) and content sanitization is applied to any data coming back. No external call is made purely on a hardcoded trigger without policy checks.

✅ Provenance & Compliance: The app attaches provenance info (sources, timestamps, etc.) to critical outputs, especially AI-generated content. Compliance checks (PII removal, allowlist enforcement) run before presenting content to users. Any output failing checks is handled via fallback or refusal as defined by policy.

✅ Verification Pipeline: If an automated verification step is part of the system, it consistently logs verification artifacts and they are accessible via debug commands. The verification does not re-run during a debug query, and every tool-backed response in production has a corresponding verification record (when verification is enabled).

✅ Thorough Testing: The test suite covers happy paths, edge cases, and malicious scenarios. Tests assert expected outputs and state changes, including for unusual inputs. All new features have associated tests, and no known critical bug is untested. Tests are reliable (no flickering tests) and maintainable.

✅ No Undocumented Modules: There are no hidden local ML models, no unvetted scripts, and no hardcoded prompt or policy content lingering in the code. All configuration is loaded from designated sources, and all machine learning or AI behavior is through official channels (e.g., calls to approved APIs). The codebase conforms to the No-Heuristic/No-Hardcode rules above in letter and spirit.