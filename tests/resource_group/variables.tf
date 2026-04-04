variable "resource_groups" {
  description = "Test input — passed through to the module."
  type = map(object({
    location   = string
    tags       = optional(map(string), {})
    lock       = optional(bool, false)
    managed_by = optional(string, "")
  }))
  default = {}
}
