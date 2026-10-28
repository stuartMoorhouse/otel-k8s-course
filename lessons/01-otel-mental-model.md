# Lesson 1: The OpenTelemetry mental model

Forget Kubernetes for a moment. OTel is four ideas.

## 1. Signals

What telemetry is made of: **traces** (a request's journey, made of *spans*), **metrics** (numbers over time), **logs**, and (newer) profiles.

## 2. Two ways data is produced

**a) Instrumentation (SDK/agent inside the app).** Code *in the app's process* creates spans and metrics. Two flavours:
- *Manual*: developers add OTel API calls.
- *Zero-code / auto*: an agent attaches to the runtime (Java `-javaagent`, Python `opentelemetry-instrument`, Node `--require`...) and instruments popular libraries (HTTP, DB clients, Redis) automatically. **This is what "instrumented" means in your Slack message.**

**b) Scraping from the outside.** The app is untouched. Something else *asks* it for numbers: Redis `INFO`, Postgres stats views, nginx `/status`. The thing that asks is a **Collector receiver**. Metrics only, mostly. No traces. **This is what "not instrumented but where a receiver exists" means.**

## 3. OTLP

The wire protocol everyone speaks (gRPC on port **4317**, HTTP on **4318**). SDKs send OTLP; Collectors receive and send OTLP; Elastic ingests OTLP.

## 4. The Collector

A standalone binary: **receivers → processors → exporters**, wired together by **pipelines**.

```
 receivers          processors            exporters
┌──────────┐      ┌───────────────┐      ┌──────────────┐
│ otlp     │      │ k8s_attributes│      │ otlp (Elastic)│
│ redis    │ ───▶ │ batch         │ ───▶ │ debug         │
│ filelog  │      │ resource...   │      │               │
└──────────┘      └───────────────┘      └──────────────┘
          one pipeline per signal type (traces / metrics / logs)
```

- **Receiver**: how data gets in (listen or scrape).
- **Processor**: modify/enrich/batch/drop.
- **Exporter**: where data goes out.
- **Extension**: helper that is not in the data path (health check, `k8s_observer`, OpAMP).
- **Connector**: exporter on one pipeline + receiver on another (rarely needed here).

Minimal config, readable now:

```yaml
receivers:
  otlp:
    protocols: { grpc: {}, http: {} }
processors:
  batch: {}
exporters:
  debug: {}
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
```

Defining a component under `receivers:` does nothing until a pipeline in `service:` uses it. Names can have a suffix: `otlp/foo` is another instance of the `otlp` type.

## Distributions (a.k.a. "distros")

The Collector is modular. Someone must *build* a binary containing chosen components.
- **core**: tiny, few components.
- **contrib**: nearly every community component (`otel/opentelemetry-collector-contrib`).
- **k8s**: a curated Kubernetes-oriented subset.
- **EDOT Collector (Elastic Distribution of OpenTelemetry)**: Elastic's build of upstream components plus Elastic-specific bits and defaults, shipped inside the Elastic Agent.

Same idea for SDKs: **EDOT Java / Node / Python / .NET / ...** are Elastic's builds of the upstream agents with Elastic defaults. They emit plain OTLP and are fully OTel-compatible.

> Rule of thumb: EDOT = upstream OTel + Elastic's packaging and defaults, not a fork you cannot compare against upstream.

## Check yourself

1. Redis isn't instrumented. Can you get traces of Redis internals? (No. You get metrics via the `redis` receiver. Client-side Redis spans come from your *app's* SDK.)
2. Which port is OTLP/HTTP? (4318)
3. A receiver is defined but never used in `service.pipelines`. What happens? (Nothing; it's inactive.)

Next: lesson 2.
