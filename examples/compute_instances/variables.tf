variable "compute_instances" {
  description = "Map of compute instances to create. See modules/compute_instance/README.md."
  type        = any
  default     = {}
}
