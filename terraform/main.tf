data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  lifecycle {
    postcondition {
      condition     = data.aws_caller_identity.current.account_id == var.expected_account_id
      error_message = "AWS profile '${var.aws_profile}' resolved to the wrong account. Check aws_profile and expected_account_id in local.auto.tfvars."
    }
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# --- Network: small VPC, 2 AZs, NAT via a single fck-nat instance (cheaper than a NAT gateway) ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = "${var.cluster_name}-vpc"
  cidr = "10.42.0.0/16"

  azs             = local.azs
  private_subnets = ["10.42.1.0/24", "10.42.2.0/24"]
  public_subnets  = ["10.42.101.0/24", "10.42.102.0/24"]

  enable_nat_gateway = false

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "fck_nat" {
  source  = "RaJiska/fck-nat/aws"
  version = "~> 1.6"

  name          = "${var.cluster_name}-fck-nat"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnets[0]
  instance_type = "t4g.nano"
  ha_mode       = true

  update_route_tables = true
  route_tables_ids    = { for i, id in module.vpc.private_route_table_ids : "private-${i}" => id }

  tags = var.tags

  # Destroy order: EKS, fck-nat -> GuardDuty cleanup -> VPC.
  depends_on = [null_resource.vpc_guardduty_cleanup]
}

# GuardDuty Runtime Monitoring creates VPC endpoints, ENIs and a security group inside the VPC
# that Terraform does not track and that block VPC deletion (DependencyViolation).
# Runs on destroy, after EKS and fck-nat are gone and before the VPC is removed:
# endpoints -> ENIs -> security groups (retried, never swallowed).
resource "null_resource" "vpc_guardduty_cleanup" {
  triggers = {
    vpc_id  = module.vpc.vpc_id
    region  = var.region
    profile = var.aws_profile
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    environment = {
      VPC_ID      = self.triggers.vpc_id
      AWS_REGION  = self.triggers.region
      AWS_PROFILE = self.triggers.profile
    }
    command = <<-EOT
      set -euo pipefail

      # 1. VPC endpoints
      eps=$(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID --query 'VpcEndpoints[].VpcEndpointId' --output text)
      if [ -n "$eps" ]; then
        aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $eps >/dev/null
      fi

      # 2. ENIs: wait up to 3 min for instance ENIs to drain, deleting the detached ones
      for i in $(seq 1 18); do
        enis=$(aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=$VPC_ID --query 'NetworkInterfaces[].NetworkInterfaceId' --output text)
        [ -z "$enis" ] && break
        for eni in $enis; do
          aws ec2 delete-network-interface --network-interface-id $eni 2>/dev/null || true
        done
        sleep 10
      done

      # 3. Non-default security groups: retry every 30s for up to 5 min
      for i in $(seq 1 10); do
        sgs=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
        [ -z "$sgs" ] && exit 0
        failed=0
        for sg in $sgs; do
          aws ec2 delete-security-group --group-id $sg || failed=1
        done
        [ "$failed" = 0 ] && exit 0
        sleep 30
      done
      echo "Security groups still present in $VPC_ID after retries" >&2
      exit 1
    EOT
  }

  depends_on = [module.vpc]
}

# --- EKS cluster + one managed node group (spot) ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Lets you run kubectl from your laptop; the creator (you) becomes cluster admin.
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    default = {
      capacity_type  = "SPOT"
      instance_types = var.node_instance_types
      min_size       = 1
      max_size       = var.node_count
      desired_size   = var.node_count

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

      # Provider default_tags do not reach launch template tag_specifications, and the
      # account rejects instance launches without the mandatory tags on the request.
      launch_template_tags = var.tags
    }
  }

  # NAT route must exist (fck-nat) before nodes launch, and the GuardDuty cleanup
  # must outlive EKS on destroy.
  depends_on = [module.fck_nat, null_resource.vpc_guardduty_cleanup]
}
