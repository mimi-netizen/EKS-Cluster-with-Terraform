
# get all available AZs in our region
data "aws_availability_zones" "available_azs" {
  state = "available"
}
data "aws_caller_identity" "current" {} # used for accesing Account ID and ARN

# get EKS cluster info to configure Kubernetes and Helm providers

data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_name
  depends_on = [
        module.eks_cluster,
        null_resource.update_kubeconfig  # Adding this for extra safety
    ]
}
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_name
}

data "aws_partition" "current_testing" {}

data "aws_caller_identity" "current_testing" {}

data "aws_eks_cluster" "cluster_testing" {
  name = module.eks_cluster.cluster_name
  depends_on = [module.eks_cluster]
}

data "aws_eks_addon_version" "this" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = module.eks_cluster.cluster_version
  most_recent        = true
}

# Get DNS name of the ELB created by the Ingress Controller.

data "kubernetes_service" "ingress_nginx" {
  depends_on = [helm_release.ingress-nginx]
  
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }
}

data "aws_route53_zone" "selected" {
  name         = var.your_domain_name  
  private_zone = false
}

data "aws_elb_hosted_zone_id" "main" {}


data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

data "tls_certificate" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}



















# data "aws_acm_certificate" "cert" {
#   arn = aws_acm_certificate.ssl_certificate.arn
# }