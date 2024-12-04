output "ebs_csi_iam_role_arn" {
  description = "IAM role arn of ebs csi"
  value       = module.ebs_csi_eks_role.iam_role_arn
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks_cluster.cluster_name}"
}

output "artifactory_url" {
  value = aws_route53_record.artifactory.name
}


# FOR CERT-MANAGER

output "ingress_lb_hostname" {
  value = data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].hostname != null ? data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].hostname : "Load balancer not ready"
}
output "cluster_oidc_issuer_url" {
  value = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  value = data.aws_iam_openid_connect_provider.eks.arn
}