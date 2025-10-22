Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: Observability (OpenTelemetry, Sentry), docs, runbooks

Objective
- Add structured logging, tracing/metrics via OpenTelemetry, optional Sentry.
- Document APIs and operations; create basic runbooks.

Deliverables
- Backend logging to JSON; request IDs, latency metrics.
- OpenTelemetry SDK configured; OTLP export hooks.
- Sentry SDK optional; DSN via env var.
- Docs: README with local dev, deploy steps, health endpoints, SLOs.

Reference-driven accelerators (copy/adapt)
- From DeliveryApp-iOS:
  - Copy `Dependencies/Analytics` into `zariz/ios/Zariz/Modules/Analytics` and wire basic track events (screen views, errors). Keep it optional under a build flag if desired.
- From next-delivery:
  - Use simple console logging patterns; optional integration with a browser SDK (e.g., Sentry) later.

Logging
```
import logging, sys, json

class JSONFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({"level": record.levelname, "msg": record.getMessage()})

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
logging.getLogger().handlers = [handler]
```

OpenTelemetry
```
pip install opentelemetry-sdk opentelemetry-instrumentation-fastapi opentelemetry-exporter-otlp
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
FastAPIInstrumentor.instrument_app(app)
```

Sentry
```
pip install sentry-sdk
import sentry_sdk, os
dsn = os.getenv('SENTRY_DSN')
if dsn:
    sentry_sdk.init(dsn=dsn, traces_sample_rate=0.1)
```

Docs & Runbooks
- README sections: Overview, Architecture, Local Dev, Testing, Deployment, Troubleshooting.
- Runbooks: DB restore, rotating JWT secret, APNs key rotation, scaling to managed DB.

Copy/Integrate
```
mkdir -p zariz/ios/Zariz/Modules/Analytics
cp -R zariz/references/DeliveryApp-iOS/Dependencies/Analytics/* zariz/ios/Zariz/Modules/Analytics/ || true
```

Verification
- Logs appear in JSON; traces export to OTLP endpoint if configured.

Next
- Release and handover in Ticket 15.
