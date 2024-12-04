# Create namespace
resource "kubernetes_namespace" "tools" {
  metadata {
    name = "tools"
    labels = {
      name = "tools"
    }
  }
}


# Helm Release for Artifactory
resource "helm_release" "artifactory" {
  name       = "artifactory"
  repository = "https://charts.jfrog.io"
  chart      = "artifactory"
  version    = "107.98.9"
  namespace  = kubernetes_namespace.tools.metadata[0].name

  values = [
   "${file("./values.yaml")}"
  ]

  timeout = 600 

  depends_on = [
    module.eks_cluster,
    kubernetes_namespace.tools,
    null_resource.update_kubeconfig 
    
  ]
}



