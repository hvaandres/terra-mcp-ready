variable "vpc_networks" {
  description = "Map of VPC networks to create. See modules/vpc_network/README.md for the schema."
  type        = any
  default     = {}
}
