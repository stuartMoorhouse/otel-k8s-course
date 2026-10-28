# Lesson 0: Prereqs and the EKS cluster

## Install tools

macOS (Homebrew):

```bash
brew install awscli terraform kubectl helm
aws --version && terraform -version && kubectl version --client && helm version
```

## AWS credentials

```bash
aws configure sso        # or `aws configure` with keys
aws sts get-caller-identity   # must succeed
```

## Create the cluster

```bash
cd otel-k8s-course/terraform
# create local.auto.tfvars (gitignored) setting aws_profile, expected_account_id and tags
terraform init
export EC_API_KEY=...   # Elastic Cloud API key, created in the target organization
terraform apply          # type "yes"; takes ~15 minutes
```

Then point kubectl at it (Terraform prints this exact command):

```bash
aws eks update-kubeconfig --region eu-west-1 --name otel-course
kubectl get nodes        # expect 2 nodes in Ready
```

If `terraform apply` complains about `cluster_version`, list what EKS supports today and set `-var cluster_version=...`:

```bash
aws eks describe-cluster-versions --region eu-west-1 --query 'clusterVersions[].clusterVersion'
```

## Get an Elastic endpoint and API key

`terraform apply` also creates a small Elastic Cloud Hosted deployment (in the organization that owns your `EC_API_KEY`). Get the values from it:

- the OTLP endpoint URL: `terraform output -raw otlp_endpoint`
- Kibana URL: `terraform output -raw kibana_endpoint`; log in as `elastic` with `terraform output -raw elasticsearch_password`
- an API key: in Kibana open **Add data → Kubernetes → OpenTelemetry** and copy the one it generates, or create one under Stack Management → API keys

(A Serverless Observability project works too: use its Managed OTLP endpoint instead.)

Export them (never commit them):

```bash
export ELASTIC_OTLP_ENDPOINT='https://...:443'
export ELASTIC_API_KEY='...'
```

## Cost control

```bash
terraform destroy        # when finished for the day. Rebuilding takes ~15 min.
```

Check: `kubectl get nodes` shows 2 Ready nodes. Go to lesson 1.
