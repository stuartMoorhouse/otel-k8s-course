# Lesson 5: Auto-instrumentation (zero-code)

## How it works

1. You annotate a pod template: `instrumentation.opentelemetry.io/inject-<language>: "<ns>/<instrumentation-name>"`.
2. At pod creation, the Operator's webhook **mutates the pod**:
   - adds an **init container** (the agent image, e.g. EDOT Python) that copies the agent into a shared volume,
   - mounts it and sets env vars (`PYTHONPATH`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, `OTEL_RESOURCE_ATTRIBUTES`...).
3. The app starts with the agent loaded and sends **OTLP to the daemon collector** (the endpoint in the `Instrumentation` CR).

Languages: `inject-java`, `inject-python`, `inject-nodejs`, `inject-dotnet`, `inject-go` (Go needs extra privileges and annotations).

Key consequence: **a pod only gets instrumented when it is (re)created.** Annotating a running pod does nothing; annotate the *pod template* so the Deployment rolls.

## Lab

```bash
kubectl apply -f manifests/demo-app.yaml
kubectl -n demo get pods           # wait for Running (pip install takes ~30s)
kubectl -n demo logs deploy/web    # should see Flask requests from the loadgen
```

Inspect the pod BEFORE instrumentation:

```bash
kubectl -n demo get pod -l app=web -o jsonpath='{.items[0].spec.initContainers}'; echo
kubectl -n demo get pod -l app=web -o jsonpath='{.items[0].spec.containers[0].env}'; echo
```

No init containers, no OTEL env vars. Now opt in:

```bash
kubectl -n demo patch deployment web --type merge -p '
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-python: "opentelemetry-operator-system/elastic-instrumentation"
'
kubectl -n demo rollout status deploy/web
```

Inspect again:

```bash
kubectl -n demo get pod -l app=web -o jsonpath='{.items[0].spec.initContainers[*].name}'; echo
kubectl -n demo get pod -l app=web -o jsonpath='{.items[0].spec.initContainers[0].image}'; echo
kubectl -n demo get pod -l app=web -o jsonpath='{range .items[0].spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}'
```

You should see an init container with an `elastic-otel-python` image and `OTEL_*` / `PYTHONPATH` env vars. Nobody touched the app code.

## See the traces

```bash
kubectl -n opentelemetry-operator-system logs ds/opentelemetry-kube-stack-daemon-collector --tail=30 | grep -i -E "traces|spans"
```

In Kibana: **Observability → Applications (APM) → Services → `demo-web`**. You should see transactions for `GET /` and Redis spans as dependencies.

## Understand what you did

- `Instrumentation` CR = **what** to inject and **where to send**.
- Pod annotation = **who** gets injected.
- The data goes **app → daemon (4318) → gateway (4317) → Elastic**.
- This gives traces/metrics/logs *from the app*. It says nothing about Redis's own internals. That's lesson 6.

## Gotchas

- Wrong/missing namespace prefix in the annotation value: the Operator looks for the CR in the pod's own namespace unless you write `ns/name`.
- Annotation on the Deployment's metadata instead of `spec.template.metadata`: silently ignored.
- Alpine/musl images can break Python/Node auto-instrumentation variants; check docs.
- OpenShift: SCCs and init-container behaviour sometimes need adjustments.

Next: lesson 6.
