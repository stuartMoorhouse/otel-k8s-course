variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use (set in local.auto.tfvars)"
  type        = string
}

variable "expected_account_id" {
  description = "AWS account ID the profile must resolve to; the plan fails otherwise (set in local.auto.tfvars)"
  type        = string
}

variable "tags" {
  description = "Tags applied to all AWS resources, including node launch templates (set in local.auto.tfvars)"
  type        = map(string)
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "otel-course"
}

variable "cluster_version" {
  description = "Kubernetes version. Check `aws eks describe-cluster-versions` for versions in standard support."
  type        = string
  default     = "1.37"
}

variable "node_instance_types" {
  description = "Spot instance types for the node group (several types improve spot availability)"
  type        = list(string)
  default     = ["t3.large", "t3a.large", "m5.large"]
}

variable "node_count" {
  type    = number
  default = 2
}

variable "elastic_version" {
  description = "Elastic Stack version: exact (e.g. 9.5.5) or 9.x.x for the latest 9.x release"
  type        = string
  default     = "9.x.x"

  validation {
    condition     = can(regex("^[0-9]+\\.([0-9]+|x)\\.([0-9]+|x)$", var.elastic_version))
    error_message = "elastic_version must look like 9.5.5, 9.5.x or 9.x.x."
  }
}

variable "elastic_hot_size" {
  description = "Elasticsearch hot tier memory (single zone, no HA)"
  type        = string
  default     = "2g"
}
