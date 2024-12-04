resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "./nginx-ingress-chart/ingress-nginx"
  # chart      = "ingress-nginx"

  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  timeout = 600

   set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

    set {
    name  = "controller.admissionWebhooks.enabled"
    value = "true"
  }


  # values = [
  #  "${file("./values.yaml")}"
  # ]

  values = [
    <<EOF
    controller:
      extraArgs:
        default-ssl-certificate: "tools/tooling-artifactory.cdk-aws.dns-dynamic.net"
    EOF
  ]

  depends_on = [
    module.eks_cluster,
    kubernetes_namespace.ingress_nginx,
    helm_release.artifactory
  ]
  
  wait   = true  
  atomic = true  


}