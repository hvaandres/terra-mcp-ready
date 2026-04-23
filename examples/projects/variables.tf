###############################################################################
# Variables — passed through to the module
#
# Consumers only need to fill in terraform.tfvars.
###############################################################################

variable "projects" {
  description = "Map of GCP projects to create. See modules/project/README.md for the schema."
  type        = any
  default     = {}
}
