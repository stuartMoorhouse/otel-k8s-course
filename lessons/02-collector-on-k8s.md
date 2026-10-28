# Lesson 2: The Collector on Kubernetes

## Deployment patterns

| Pattern | K8s object | Use it for |
|---------|-----------|------------|
| **Agent / daemon** | DaemonSet (1 pod per node) | Things that are *per node*: apps send OTLP to the local node; host/kubelet metrics; container log files from `/var/log/pods`; **discovery of workloads on that node** |
| **Gateway** | Deployment (+ HPA) | Central egress: batching, retries, auth to Elastic, tail sampling. Apps/agents send here. |
| **Cluster** | Deployment, 1 replica | Things that must be collected **once** per cluster: Kubernetes events, cluster-level metrics (`k8s_cluster`). Run as daemonset and you'd get N duplicates. |
| **Sidecar** | Extra container in a pod | Rare; per-pod isolation |

Elastic's reference setup (your colleague's file) uses exactly three: **cluster**, **daemon**, **gateway**.

```
 app pods ──OTLP──▶ DAEMON (per node) ──OTLP──▶ GATEWAY ──OTLP──▶ Elastic
                      ▲  also: receiver_creator, kubeletstats, hostmetrics, logs
 K8s API ──▶ CLUSTER collector (events, cluster metrics) ──▶ GATEWAY
```

## The Kubernetes-specific components you must know

| Component | Type | What it does |
|-----------|------|--------------|
| `k8s_attributes` | processor | Adds `k8s.pod.name`, `k8s.namespace.name`, `k8s.deployment.name`... to telemetry by looking the pod up in the K8s API. Needs **RBAC**. |
| `k8s_cluster` | receiver | Cluster-state metrics (pod phase, deployment replicas). |
| `k8s_events` | receiver | K8s Events as logs. |
| `kubeletstats` | receiver | CPU/memory per pod/container from each node's kubelet. |
| `hostmetrics` | receiver | Node OS metrics. |
| `filelog` | receiver | Reads container log files. |
| `k8s_observer` | **extension** | Watches the K8s API and publishes "endpoints" (pods, ports, services, nodes). Does not collect data itself. |
| `receiver_creator` | receiver | Starts *other receivers* when an observer's endpoint matches a rule or annotation. **Lesson 6.** |
| `resourcedetection` | processor | Adds cloud/host info (EKS, GCP, AKS cluster name...). |

## RBAC: the #1 K8s-specific failure

Components that talk to the K8s API run as the Collector pod's **ServiceAccount**. If its ClusterRole lacks `list`/`watch` on pods/nodes etc., you get errors like `pods is forbidden` in the logs and missing attributes or no discovery. The Helm chart creates the ClusterRole; custom needs add rules (your colleague's file adds `events` for `k8s_events`).

## Exercise (reading only)

Open `helm/lab-values.yaml` and find:
1. The extension that watches K8s.
2. The receiver that consumes it.
3. The pipeline that sends discovered metrics to the gateway.
4. Why `logs: null`, `metrics: null`, `traces: null` appear in the daemon pipelines. (Switch off the chart's default pipelines so ours replace them.)

Next: lesson 3.
