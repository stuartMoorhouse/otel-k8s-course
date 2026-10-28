output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "kibana_endpoint" {
  value = ec_deployment.this.kibana.https_endpoint
}

output "elasticsearch_endpoint" {
  value = ec_deployment.this.elasticsearch.https_endpoint
}

output "otlp_endpoint" {
  description = "Value for ELASTIC_OTLP_ENDPOINT (OTLP gRPC on the Integrations Server)"
  value       = "${trimsuffix(ec_deployment.this.integrations_server.endpoints.apm, ":443")}:443"
}

output "elastic_version" {
  value = ec_deployment.this.version
}

output "elasticsearch_username" {
  value = ec_deployment.this.elasticsearch_username
}

output "elasticsearch_password" {
  description = "Elastic superuser password (demo only). Read with: terraform output -raw elasticsearch_password"
  value       = ec_deployment.this.elasticsearch_password
  sensitive   = true
}
