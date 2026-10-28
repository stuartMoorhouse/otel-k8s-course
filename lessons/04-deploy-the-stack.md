# Lesson 4: Deploy the stack

Run from the `otel-k8s-course` directory.

## 1. Namespace and secret

```bash
kubectl create namespace opentelemetry-operator-system

kubectl -n opentelemetry-operator-system create secret generic elastic-secret-otel \
  --from-literal=elastic_otlp_endpoint="$ELASTIC_OTLP_ENDPOINT" \
  --from-literal=elastic_api_key="$ELASTIC_API_KEY"
```

(Same secret name and keys Elastic's reference file uses, so lesson 7 matches.)

## 2. Install the chart

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Optional: pin the version noted in Elastic's values file
# helm search repo open-telemetry/opentelemetry-kube-stack --versions | head
helm install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
  --namespace opentelemetry-operator-system \
  --values helm/lab-values.yaml
```

> If the install fails on a chart-level error such as a CRD or webhook not ready, wait 30s and run `helm upgrade --install` again with the same arguments; the webhook starts after the Operator pod.

## 3. Look at what you got

```bash
kubectl -n opentelemetry-operator-system get pods
kubectl get crds | grep opentelemetry
kubectl -n opentelemetry-operator-system get opentelemetrycollectors
kubectl -n opentelemetry-operator-system get instrumentation
kubectl -n opentelemetry-operator-system get daemonset,deployment,svc
```

Expected: an operator pod, one daemon pod per node, one gateway pod; two `OpenTelemetryCollector` resources; one `Instrumentation` named `elastic-instrumentation`.

Note the *Operator created* the DaemonSet from the CR:

```bash
kubectl -n opentelemetry-operator-system get ds opentelemetry-kube-stack-daemon-collector -o yaml | grep -A3 ownerReferences
kubectl -n opentelemetry-operator-system get cm | grep daemon     # the generated Collector config
```

## 4. Debugging toolbox (you will use these forever)

```bash
# Collector logs: errors about RBAC, config, exporters show up here
kubectl -n opentelemetry-operator-system logs ds/opentelemetry-kube-stack-daemon-collector --tail=50
kubectl -n opentelemetry-operator-system logs deploy/opentelemetry-kube-stack-gateway-collector --tail=50

# Operator logs: why a CR or a webhook failed
kubectl -n opentelemetry-operator-system logs deploy/opentelemetry-kube-stack-operator --tail=50

# The config the Collector actually runs
kubectl -n opentelemetry-operator-system get cm -o yaml | less
```

Common failures:

| Symptom | Cause |
|---------|-------|
| `... is forbidden: User "system:serviceaccount:..." cannot list ...` | Missing ClusterRole rule (RBAC) |
| `unknown type: "otlp_grpc"` / `unknown type: "otlp"` | Exporter type name differs by Collector version. Match the image |
| Gateway: `401/403` from Elastic | Wrong API key or endpoint |
| `failed calling webhook` on pod/CR create | Operator pod not ready / cert issue; wait, retry |

## 5. Confirm data reaches Elastic

Gateway logs with `debug` exporter show batches. In Kibana, check **Observability → Infrastructure / APM / Discover** (logs-/metrics-/traces- data streams) for data. It will be empty of app data until lesson 5.

Next: lesson 5.
