# EKS Cluster Module Configuration
module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.14"

  cluster_name    = var.cluster_name
  cluster_version = "1.25"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  enable_irsa = true

  cluster_addons = {
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  self_managed_node_group_defaults = {
    instance_type                          = var.asg_instance_types[0]
    update_launch_template_default_version = true
    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy          = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      AmazonEKSWorkerNodePolicy         = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
      AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    }
  }

  self_managed_node_groups = local.self_managed_node_groups

  # Auth Configuration
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true
  aws_auth_users           = concat(local.admin_user_map_users, local.developer_user_map_users)

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}

# Wait for cluster to be ready
resource "time_sleep" "wait_for_cluster" {
  depends_on = [module.eks_cluster]
  create_duration = "30s"
}

# EBS CSI Driver Role
module "ebs_csi_eks_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "ebs-csi-driver-role"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks_cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  depends_on = [time_sleep.wait_for_cluster]
}

# Service Account for EBS CSI Driver
resource "kubernetes_service_account" "ebs_csi_controller_sa" {
  metadata {
    name      = "ebs-csi-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.ebs_csi_eks_role.iam_role_arn
    }
    labels = {
      "app.kubernetes.io/name"      = "aws-ebs-csi-driver"
      "app.kubernetes.io/component" = "controller"
    }
  }

  depends_on = [module.ebs_csi_eks_role]
}

# EBS CSI Driver Add-on
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = module.eks_cluster.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  addon_version               = data.aws_eks_addon_version.this.version
  configuration_values        = null
  preserve                    = true
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = module.ebs_csi_eks_role.iam_role_arn

  depends_on = [
    kubernetes_service_account.ebs_csi_controller_sa,
    time_sleep.wait_for_cluster
  ]
}


# Update Kubeconfig
resource "null_resource" "update_kubeconfig" {
  depends_on = [time_sleep.wait_for_cluster]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks_cluster.cluster_name} --region ${var.aws_region} --kubeconfig ${path.module}/kubeconfig"
  }

  triggers = {
    cluster_endpoint = module.eks_cluster.cluster_endpoint
    cluster_name     = module.eks_cluster.cluster_name
  }
}
