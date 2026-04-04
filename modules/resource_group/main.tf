###############################################################################
# Resource Groups
###############################################################################

resource "azurerm_resource_group" "this" {
  for_each = var.resource_groups

  name       = each.key
  location   = each.value.location
  tags       = each.value.tags
  managed_by = each.value.managed_by != "" ? each.value.managed_by : null
}

###############################################################################
# Management Locks — Conditional on lock = true
###############################################################################

resource "azurerm_management_lock" "this" {
  for_each = {
    for name, rg in var.resource_groups : name => rg if rg.lock
  }

  name       = "lock-${each.key}-do-not-delete"
  scope      = azurerm_resource_group.this[each.key].id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform — do not delete."
}
