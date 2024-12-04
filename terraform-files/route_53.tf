resource "aws_route53_record" "artifactory" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.subdomain 
  type    = "A"

  alias {
    name                   = data.kubernetes_service.ingress_nginx.status.0.load_balancer.0.ingress.0.hostname
    zone_id               =  "Z24FKFUX50B4VW" # Gets the canonical hosted zone ID for ELB
    evaluate_target_health = true
  }

  depends_on = [
    helm_release.ingress-nginx,
  ]
}


# data.aws_elb_hosted_zone_id.main.id