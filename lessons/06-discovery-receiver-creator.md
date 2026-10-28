# Lesson 6: Auto-discovery with receiver_creator

The topic of your original Slack message.

## The problem

Redis, Postgres, nginx... are not instrumented and you will not change them. But the Collector has receivers that scrape them. You don't want to hand-write a receiver config per pod, and pods come and go.

## The pieces

```
K8s API ──▶ k8s_observer (extension) ──"endpoints"──▶ receiver_creator ──starts──▶ redis receiver ──▶ pipeline
                    pods, ports, services, nodes          rules or annotations       (one per matching pod)
```

- **`k8s_observer`** publishes what exists in the cluster. It collects no telemetry.
- **`receiver_creator`** creates/destroys receivers dynamically, **per endpoint**. Pod goes away → receiver stops.
- Two ways to say *which* receiver for *which* pod:

### Way A: rules in the Collector config (central)

```yaml
receiver_creator:
  watch_observers: [k8s_observer]
  receivers:
    redis:
      rule: type == "port" && port == 6379
      config:
        collection_interval: 15s
```

Platform team owns it. "Any pod exposing 6379 is Redis." Fast, but guesses by port/name.

### Way B: annotation-driven "discovery" (decentralised, used in Elastic's values)

```yaml
receiver_creator/metrics:
  watch_observers: [k8s_observer]
  discovery:
    enabled: true
```

The **workload owner** annotates the pod:

```yaml
io.opentelemetry.discovery.metrics/enabled: "true"
io.opentelemetry.discovery.metrics/scraper: redis
io.opentelemetry.discovery.metrics/config: |
  collection_interval: "15s"
```

The Collector then builds the `redis` receiver config itself, with `endpoint` = `<pod-ip>:<container-port>` automatically. For multi-container pods, target a port: `io.opentelemetry.discovery.metrics.6379/enabled`. Same idea for logs with `io.opentelemetry.discovery.logs/enabled` (starts a `filelog` receiver on that pod's log files).

Stability: per upstream docs, receiver_creator is **beta for metrics, alpha for logs/traces/profiles**. Say that to customers.

(Customers often say "labels or annotations". The built-in hints feature uses **annotations**. Rules in Way A can match labels too: `labels["app"] == "redis"`.)

## Lab

Redis is running but unannotated. Check nothing is scraped yet:

```bash
kubectl -n opentelemetry-operator-system logs ds/opentelemetry-kube-stack-daemon-collector | grep -i redis
```

Annotate it:

```bash
kubectl -n demo patch deployment redis --patch-file manifests/redis-discovery-patch.yaml
kubectl -n demo rollout status deploy/redis
```

Watch the daemon on the node where Redis landed:

```bash
NODE=$(kubectl -n demo get pod -l app=redis -o jsonpath='{.items[0].spec.nodeName}')
kubectl -n opentelemetry-operator-system get pod -o wide | grep daemon     # find the pod on $NODE
kubectl -n opentelemetry-operator-system logs <that-pod> --tail=50 | grep -i -E "redis|receiver_creator|started"
```

You should see a receiver start for the Redis pod, then `redis.*` metrics flowing (the `debug` exporter prints counts per batch). In Kibana (Discover or Metrics), look for `redis.clients.connected`, `redis.commands.processed`, with `k8s.pod.name` and `k8s.namespace.name` attached by `k8s_attributes`.

Prove it's dynamic:

```bash
kubectl -n demo scale deploy/redis --replicas=0   # receiver stops
kubectl -n demo scale deploy/redis --replicas=1   # new receiver starts
```

## Why the DaemonSet runs discovery

With `k8s_observer.node` set to the daemon's own node (`${env:OTEL_K8S_NODE_NAME}`, as in `lab-values.yaml`), each daemon only sees pods on its node: one scraper per pod, no duplicates, no cross-node traffic. **Without `node:`, every daemon sees every pod in the cluster and you get N copies of each metric.** Elastic's reference file doesn't set it (verify the behaviour on your version; this is a good question to raise with the product team). Running discovery on a single gateway Deployment also works, but all scrapers then run in one process and you lose per-node scaling.

## Customer checklist (what to ask)

1. Which apps? Is there a Collector receiver for each (`redis`, `postgresql`, `mysql`, `mongodb`, `nginx`...)? It must be **in the Collector image they run** (contrib has them; EDOT Collector: check its component list).
2. Credentials: DB receivers need username/password. Do **not** put them in annotations. Use secrets/env vars in the Collector config.
3. RBAC: Collector ServiceAccount can list/watch pods, nodes, services (and ingresses if observed).
4. OpenShift: SCCs for the daemon (hostNetwork/root are often blocked); check if the Operator and webhook run.
5. Rollout: annotations live in the **pod template**, so adding them restarts workloads.
6. Scope: metrics (beta) and logs (alpha). Traces need instrumentation (lesson 5).

Next: lesson 7.
