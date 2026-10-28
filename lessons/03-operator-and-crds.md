# Lesson 3: The Operator, CRDs and the kube-stack chart

## Operator pattern (30-second refresher)

A **CRD** adds a new resource type to Kubernetes. An **operator** is a controller that watches those resources and creates the real objects (Deployments, DaemonSets, ConfigMaps...) for you.

## Who made what

| Thing | Owner | What it is |
|-------|-------|-----------|
| **OpenTelemetry Operator** | Upstream OTel project (CNCF) | The controller + CRDs |
| **`opentelemetry-kube-stack` Helm chart** | Upstream OTel (`opentelemetry-helm-charts`) | Installs the Operator **and** opinionated Collector CRs (daemon, cluster, gateway) in one go |
| **Collector images** | Upstream (`otel/opentelemetry-collector-contrib`) or Elastic (EDOT inside the Elastic Agent image) | Binary that runs in the pods |
| **Elastic `values.yaml`** | Elastic | Configuration for the upstream chart: wires collectors to Elastic, adds OpAMP/Fleet, picks EDOT instrumentation images |
| **EDOT SDK images** (`docker.elastic.co/observability/elastic-otel-*`) | Elastic | Auto-instrumentation agents, injected by the Operator |

So: *Elastic did not make the Operator*. Elastic ships config and images that plug into it.

## The CRDs you will see

**`OpenTelemetryCollector`**: "run a Collector with this config", with `mode:` `daemonset`, `deployment`, `statefulset` or `sidecar`. The Operator turns it into the matching K8s objects. In kube-stack, each entry under `collectors:` (daemon, cluster, gateway) becomes one of these.

**`Instrumentation`**: "here are the auto-instrumentation images and exporter settings". Does nothing alone. Pods opt in via an annotation (lesson 5). The Operator's mutating **admission webhook** then rewrites the pod at creation, adding an init container with the agent and env vars.

**`TargetAllocator`** (optional, off in the lab): shards Prometheus scraping across Collectors. Ignore for now.

## Why a webhook and certificates matter

The webhook needs TLS. Options: cert-manager (recommended for production) or the chart's `autoGenerateCert` (what the lab and your colleague's file use). That's the `admissionWebhooks.certManager` block in the values.

## Naming rule you'll use daily

An `OpenTelemetryCollector` named `X` creates workloads and services named **`X-collector`**. So `fullnameOverride: opentelemetry-kube-stack-daemon` gives the DaemonSet `opentelemetry-kube-stack-daemon-collector` and a Service with the same name.

Next: lesson 4, deploy it.
