# OpenTelemetry on Kubernetes: a hands-on course

Goal: understand conversations like *"auto-discover Redis with receiver_creator on OpenShift"* or *"use the Operator with the EDOT instrumentation images"*, because you have built and broken each piece yourself.

Prerequisite: basic Kubernetes (pods, deployments, services, namespaces, `kubectl`).
Time: ~6-8 hours, spread over a few sessions.

## Lessons

| # | Lesson | You will be able to say... |
|---|--------|----------------------------|
| 0 | [Prereqs and EKS cluster](lessons/00-prereqs-and-cluster.md) | "I have a cluster to break." |
| 1 | [The OTel mental model](lessons/01-otel-mental-model.md) | what an SDK, the Collector, OTLP, a receiver, a distro and EDOT are |
| 2 | [The Collector on Kubernetes](lessons/02-collector-on-k8s.md) | why agent (daemonset) + gateway (deployment) |
| 3 | [The Operator, CRDs and the kube-stack chart](lessons/03-operator-and-crds.md) | who made what: upstream vs Elastic |
| 4 | [Deploy the stack](lessons/04-deploy-the-stack.md) | I installed it and read its pieces |
| 5 | [Auto-instrumentation](lessons/05-auto-instrumentation.md) | how traces appear without code changes |
| 6 | [Auto-discovery with receiver_creator](lessons/06-discovery-receiver-creator.md) | how Redis metrics appear with no app changes |
| 7 | [Reading Elastic's reference values.yaml](lessons/07-read-elastics-values.md) | I can read that Slack config line by line |
| 8 | [Decoder and cheat sheet](lessons/08-decoder-and-cheatsheet.md) | glossary, common gotchas, how to answer customers |

## Files

- `terraform/`: small EKS cluster in eu-west-1 (2x spot t3.large, fck-nat) plus a small Elastic Cloud Hosted deployment (`EC_API_KEY` of the target org must be set). Requires a gitignored `terraform/local.auto.tfvars` defining `aws_profile`, `expected_account_id` and `tags`. Roughly $0.30-0.40/hour while running. **Run `terraform destroy` when done.**
- `helm/lab-values.yaml`: a small version of Elastic's `opentelemetry-kube-stack` values.
- `manifests/`: demo app (Flask + Redis + load generator) and the discovery annotations patch.

## Caveats (read once)

- I wrote the lab files from the config you pasted plus the upstream receiver_creator README. I couldn't run them against a live cluster. Expect to fix a small thing or two (chart key names, versions). Lesson 4 shows how to debug.
- Versions (Collector `0.164.0`, EDOT agent images, kube-stack chart `0.25.1`) were the latest as of 2026-10-28; the chart is installed unpinned, so it may have moved. Check Elastic's operator README: https://github.com/elastic/opentelemetry/blob/main/docs/kubernetes/operator/README.md
