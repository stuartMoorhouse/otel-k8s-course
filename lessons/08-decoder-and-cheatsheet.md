# Lesson 8: Decoder and cheat sheet

## Slack decoder

| You hear | It means |
|----------|----------|
| "collector receiver" | Any receiver component in an OTel Collector (not a named component) |
| "instrumented" | An SDK/agent runs inside the app and emits traces/metrics/logs |
| "not instrumented, but a receiver exists" | Scrape from outside with a Collector receiver (metrics, sometimes logs) |
| "auto-discovery" | Collector finds targets via the K8s API (`k8s_observer` + `receiver_creator`) |
| "auto-instrumentation" / "zero-code" | **Operator injects an SDK** into pods. Different thing from discovery! |
| "the Operator" | The upstream OpenTelemetry Operator |
| "kube-stack" | Upstream Helm chart that installs the Operator + collectors |
| "EDOT" | Elastic Distribution of OpenTelemetry (Collector and language SDKs) |
| "daemon / gateway / cluster collector" | The three Collector roles, see lesson 2 |
| "OpAMP" | Protocol for remote Collector management (Fleet) |
| "OTLP" | OTel wire protocol: gRPC 4317, HTTP 4318 |
| "contrib" | Upstream Collector build with nearly all community components |
| "tail-based sampling (TBS)" | Decide to keep a trace after seeing all of it; needs all spans of a trace in one place |
| "hints" | The annotation-based receiver_creator discovery |

## Two things people conflate

|  | Auto-**discovery** | Auto-**instrumentation** |
|---|---|---|
| Needs app to be modified/injected? | No | Yes (agent injected at pod start) |
| Mechanism | `k8s_observer` + `receiver_creator` | Operator webhook + `Instrumentation` CR |
| Output | Metrics (logs) of **the target** (Redis, Postgres...) | Traces/metrics/logs **from the app** |
| Opt-in | Pod annotation `io.opentelemetry.discovery.*` | Pod annotation `instrumentation.opentelemetry.io/inject-*` |
| Maturity | receiver_creator: metrics beta, logs alpha | Mature for Java/Python/Node/.NET; Go is more involved |

## Customer answer template (the Slack question)

> Yes. For databases, Redis and similar workloads that aren't instrumented, use the Collector's `receiver_creator` with the `k8s_observer`. With discovery enabled, workload owners annotate pods (`io.opentelemetry.discovery.metrics/enabled`, `.../scraper`, `.../config`) and the daemon collector starts the matching receiver per pod (redis, postgresql, mysql...) and stops it when the pod goes away. It works on Kubernetes and OpenShift, needs RBAC to list/watch pods, and depends on the receiver existing in the Collector build (contrib has them; check the EDOT Collector component list). Metrics support is beta. Credentials should come from secrets, not annotations. Traces still require instrumentation.

## Command cheat sheet

```bash
NS=opentelemetry-operator-system
kubectl -n $NS get opentelemetrycollectors,instrumentation
kubectl -n $NS logs ds/opentelemetry-kube-stack-daemon-collector --tail=100
kubectl -n $NS logs deploy/opentelemetry-kube-stack-gateway-collector --tail=100
kubectl -n $NS logs deploy/opentelemetry-kube-stack-operator --tail=100
kubectl -n $NS get cm | grep collector            # generated configs
kubectl auth can-i list pods --as system:serviceaccount:$NS:opentelemetry-kube-stack-daemon   # RBAC check
helm -n $NS get values opentelemetry-kube-stack
helm -n $NS upgrade opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack -f helm/lab-values.yaml
```

## Further experiments

1. Add a Postgres deployment and annotate it with `scraper: postgresql` (needs credentials in a secret, see the upstream `postgresqlreceiver` README).
2. Switch `defaultCRConfig.image` to the Elastic Agent image shown commented-out in Elastic's file and see which components are missing.
3. Turn on the cluster collector (`k8s_events`, `k8s_cluster`) from Elastic's file.
4. Break RBAC on purpose (remove `pods` from the ClusterRole) and read the errors.
5. Try cert-manager instead of `autoGenerateCert`.
6. Read the upstream docs: `receivercreator`, `k8sobserver`, `k8sattributesprocessor`, Operator auto-instrumentation.

When done: `cd terraform && terraform destroy`.
