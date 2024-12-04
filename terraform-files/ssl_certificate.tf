
# resource "aws_iam_role" "cert_manager_role" {
#   name = "cert_manager_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           Federated = data.aws_iam_openid_connect_provider.eks.arn
#         },
#         Action = "sts:AssumeRoleWithWebIdentity",
#         Condition = {
#            StringEquals = {
#             "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud": "sts.amazonaws.com",
#             "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:default:example-sa"
#           }
#         }
#       }
#     ]
#   })
# }






# # IAM Policy for cert-manager to Manage Route53 Records
# resource "aws_iam_role_policy_attachment" "cert_manager_route53_access" {
#   role       = aws_iam_role.cert_manager_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
# }

# # Inline policy attachment using the custom JSON policy file
# resource "aws_iam_role_policy" "cert_manager_custom_inline_policy" {
#   name   = "cert_manager_custom_policy"
#   role   = aws_iam_role.cert_manager_role.name
#   policy = file("https-cert/cert-manager-policy.json")  # Update this with the actual path to your JSON file
# }





# # Attach the policy to the role
# resource "aws_iam_role_policy_attachment" "cert_manager" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
#   role       = aws_iam_role.cert_manager_role.name
# }





# Kubernetes Namespace for cert-manager
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = var.cert_manager_namespace
    labels = {
      name = var.cert_manager_namespace
    }
  }
}

# # Kubernetes Service Account for cert-manager
# resource "kubernetes_service_account" "cert_manager" {
#   metadata {
#     name      = "cert-manager"
#     namespace = kubernetes_namespace.cert_manager.metadata[0].name
#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.cert_manager_role.arn
#     }
#   }

#   automount_service_account_token = true

#   depends_on = [
#     kubernetes_namespace.cert_manager,
#     aws_iam_role.cert_manager_role
#   ]
# }
# # ClusterRole for cert-manager
# resource "kubernetes_cluster_role" "cert_manager" {
#   metadata {
#     name = "cert-manager"
#   }

#   rule {
#     api_groups = [""]
#     resources  = ["serviceaccounts", "serviceaccounts/token"]
#     verbs      = ["create"]
#   }

#   rule {
#     api_groups = ["cert-manager.io"]
#     resources  = ["certificaterequests"]
#     verbs      = ["get", "list", "watch", "create", "update", "patch"]
#   }
# }

# # ClusterRoleBinding for cert-manager
# resource "kubernetes_cluster_role_binding" "cert_manager_acme_binding" {
#   metadata {
#     name = "cert-manager-acme-binding"
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = kubernetes_cluster_role.cert_manager.metadata[0].name
#   }

#   subject {
#     kind      = "ServiceAccount"
#     name      = kubernetes_service_account.cert_manager.metadata[0].name
#     namespace = kubernetes_namespace.cert_manager.metadata[0].name
#   }
# }


# Helm Release for cert-manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  create_namespace = false  # Namespace is created separately

  timeout = 600  # 10 minutes
  wait    = true
  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  # set {
  #   name  = "serviceAccount.name"
  #   value = kubernetes_service_account.cert_manager.metadata[0].name
  # }

 # Optional: Customize additional values here
  values = [file("./https-cert/cert-values.yaml")]

  depends_on = [
    
      helm_release.artifactory,
      # null_resource.apply_artifactory_ingress
  
  
  ]
}

resource "null_resource" "wait_for_cert_manager_crds" {
  depends_on = [helm_release.artifactory]

  provisioner "local-exec" {
    command = <<EOF
      kubectl wait --for=condition=Established --timeout=600s \
        crd/certificates.cert-manager.io \
        crd/clusterissuers.cert-manager.io \
        crd/issuers.cert-manager.io
    EOF
  }
}

resource "null_resource" "wait_for_cert_manager_pods" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {

    command = "kubectl wait --for=condition=Ready pods -n ${kubernetes_namespace.cert_manager.metadata[0].name} --all --timeout=300s"
  }
}


resource "kubectl_manifest" "apply_secret" {
  yaml_body = file("${path.module}/secrets.yaml")
}

resource "helm_release" "cert_manager_clusterissuer" {
  name       = "cert-manager-clusterissuer"
  chart      = "cert-manager-clusterissuer"  # Name of your local chart
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  repository = "file://${path.module}/cert-manager-clusterissuer"  # Path to your local chart

  create_namespace = false  # Namespace is already created

  wait     = true
  timeout  = 300  # Adjust as needed

  depends_on = [
    helm_release.cert_manager  # Ensure cert-manager is installed first
  ]
}


