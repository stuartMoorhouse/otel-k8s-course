# Lesson 7: Reading Elastic's reference values.yaml

The file your colleague pasted is Elastic's `values.yaml` for the upstream `opentelemetry-kube-stack` chart. Reference: https://github.com/elastic/opentelemetry/blob/main/docs/kubernetes/operator/README.md

## Map of the file (top to bottom)

| Section | What it does | Lab equivalent |
|---------|-------------|----------------|
| `opentelemetry-operator:` | Operator settings; `--enable-go-instrumentation`; webhook certs (autoGenerate vs cert-manager) | same, smaller |
| `crds.create` | Install the CRDs with the chart | same |
| `defaultCRConfig.image` | Collector image for all CRs. Commented lines show the Elastic Agent (EDOT) image; active line is upstream contrib | same |
| `defaultCRConfig.targetAllocator` | Off | same |
| `clusterRole.rules` | Extra RBAC: `configmaps`, and `events` for `k8s_events` | we add pods/nodes/etc. |
| `clusterName` | Sets `k8s.cluster.name` where it can't be auto-detected | not set |
| **`collectors.cluster`** | **Deployment, 1 replica.** `k8s_events` (events → logs), `k8s_cluster` (cluster metrics). → gateway | disabled in lab |
| **`collectors.daemon`** | **DaemonSet.** `otlp` in, `hostmetrics`, `kubeletstats`, `receiver_creator/logs` + `/metrics` (discovery), `k8s_attributes`, JSON log parsing → gateway | simplified |
| **`collectors.gateway`** | **Deployment + autoscaler (2-5).** `otlp` in, big batching queues, → Elastic OTLP endpoint. Traces first go to `otlp/tbs` (a **tail-based sampling** service) | simplified, direct to Elastic |
| `instrumentation:` | The `Instrumentation` CR: propagators, 100% sampling, EDOT images per language | same |

## Details that will confuse you in a meeting

**`ELASTIC_AGENT_OTEL: '"true"'`**: tells the Elastic Agent image to run in OTel Collector mode. Only matters with the Elastic image.

**`opamp:` extension + `ELASTIC_FLEET_*` env**: OpAMP is an OTel protocol for remote management. Here the Collectors register with Elastic **Fleet** so Kibana can show them as managed agents. Not required for data flow.

**`service.telemetry`**: the Collector's *own* logs and metrics, pushed to the gateway on port 4319 (`otlp/telemetry` receiver) so you can monitor the Collectors themselves.

**Daemon `hostNetwork: true`, `runAsUser: 0`, `/var/log/pods` mount**: needed for host metrics and container logs. These are what OpenShift SCCs tend to object to.

**`receiver_creator/logs` with `default_annotations: io.opentelemetry.discovery.logs/enabled: "true"`**: logs discovery is **on by default for every pod** (the default annotation), unlike metrics, where each pod must opt in. That is why a commented-out `filelog` block sits next to it: discovery replaces the static filelog.

**`pipelines: logs: null ...`**: removes the chart's default pipelines so the explicit ones win.

**Gateway `sending_queue ... sizer: bytes`**: backpressure/batching tuned for Elastic. `batch/metrics` with `send_batch_max_size: 0`: don't split metric batches (avoids TSDB version conflicts).

**`transform/servertoclient`**: a gateway processor that rewrites span kind from an attribute (a workaround for specific data).

**Exporter named `otlp_grpc/...`**: the gRPC OTLP exporter. Older Collectors called it `otlp`.

## Exercise

Without looking back, answer:

1. Where does a Redis metric travel from pod to Elastic? *(redis receiver started by receiver_creator in the daemon on that node → `k8s_attributes` → batch → daemon exporter → gateway → Elastic.)*
2. Where does a Python app's trace go? *(Injected EDOT Python → daemon OTLP 4318 → gateway → `otlp/tbs` tail sampling → Elastic.)*
3. Why is `k8s_events` in the cluster collector, not the daemon? *(You'd get one copy per node.)*
4. Why would this fail on OpenShift out of the box? *(SCC: hostNetwork, root, hostPath; webhook certs; check.)*
5. Is the Operator Elastic's? *(No: upstream. Elastic provides values and images.)*

Next: lesson 8.
