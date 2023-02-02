locals {
  name            = try(var.helm_config.name, "external-dns")
  service_account = try(var.helm_config.service_account, "${local.name}-sa")

  argocd_gitops_config = merge(
    {
      enable             = true
      serviceAccountName = local.service_account
    },
    var.helm_config
  )
}

module "helm_addon" {
  source = "../helm-addon"

  # https://github.com/bitnami/charts/blob/main/bitnami/external-dns/Chart.yaml
  helm_config = merge(
    {
      description = "ExternalDNS Helm Chart"
      name        = local.name
      chart       = local.name
      repository  = "https://charts.bitnami.com/bitnami"
      version     = "6.11.2"
      namespace   = local.name
      values = [
        <<-EOT
          provider: aws
          aws:
            region: ${var.addon_context.aws_region_name}
        EOT
      ]
    },
    var.helm_config
  )

  set_values = concat(
    [
      {
        name  = "serviceAccount.name"
        value = local.service_account
      },
      {
        name  = "serviceAccount.create"
        value = false
      }
    ],
    try(var.helm_config.set_values, [])
  )

  irsa_config = {
    create_kubernetes_namespace         = try(var.helm_config.create_namespace, true)
    kubernetes_namespace                = try(var.helm_config.namespace, local.name)
    create_kubernetes_service_account   = true
    create_service_account_secret_token = try(var.helm_config["create_service_account_secret_token"], false)
    kubernetes_service_account          = local.service_account
    irsa_iam_policies                   = var.irsa_policies
  }

  addon_context     = var.addon_context
  manage_via_gitops = var.manage_via_gitops
}

