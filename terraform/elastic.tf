locals {
  ec_region = "aws-${var.region}"

  # "9.x.x" -> ^9\.[0-9]+\.[0-9]+$ (latest 9.x); "9.5.5" -> ^9\.5\.5$ (exact).
  version_regex = "^${replace(replace(var.elastic_version, ".", "\\."), "x", "[0-9]+")}$"
}

data "ec_stack" "this" {
  version_regex = local.version_regex
  region        = local.ec_region
  # Pin the resolved version in state so a new release does not upgrade the
  # deployment on the next apply.
  lock = true
}

# Small single-zone Elastic Cloud Hosted deployment for the course (no HA, no ML,
# no frozen tier). Integrations Server provides the OTLP endpoint the gateway
# collector sends to. The deployment is created in the organization that owns EC_API_KEY.
resource "ec_deployment" "this" {
  name                   = var.cluster_name
  region                 = local.ec_region
  version                = data.ec_stack.this.version
  deployment_template_id = "aws-general-purpose"

  elasticsearch = {
    autoscale = false

    hot = {
      size          = var.elastic_hot_size
      size_resource = "memory"
      zone_count    = 1
      autoscaling   = {}
    }
  }

  kibana = {
    size          = "1g"
    size_resource = "memory"
    zone_count    = 1
  }

  integrations_server = {
    size          = "1g"
    size_resource = "memory"
    zone_count    = 1
  }

  tags = merge(var.tags, { name = var.cluster_name })
}
