# Self-service variable files land in subnets/<name>.yaml
#
# In production, replace null_resource with:
#   - resource "bluecat_network"
#   - resource "bluecat_host_record"

locals {
  subnets = {
    for f in fileset("${path.module}/subnets", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/subnets/${f}"))
  }
}

# Represents bluecat_network
resource "null_resource" "network" {
  for_each = local.subnets

  triggers = {
    subnet_name   = each.key
    cidr          = each.value.cidr
    gateway       = each.value.gateway
    configuration = each.value.configuration
    view          = each.value.view
    parent_block  = each.value.parent_block
  }
}

# Represents bluecat_host_record for the gateway
resource "null_resource" "gw_record" {
  for_each = { for k, v in local.subnets : k => v if v.dns_enabled }

  triggers = {
    fqdn    = "gw.${each.key}.internal"
    ip      = each.value.gateway
    view    = each.value.view
  }

  depends_on = [null_resource.network]
}

output "provisioned_subnets" {
  description = "Summary of subnets managed by this workspace"
  value = {
    for k, v in local.subnets : k => {
      cidr          = v.cidr
      gateway       = v.gateway
      configuration = v.configuration
      dns_record    = v.dns_enabled ? "gw.${k}.internal" : "disabled"
    }
  }
}
