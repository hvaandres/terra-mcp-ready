###############################################################################
# Variables — passed through to the module
###############################################################################

variable "storage_buckets" {
  description = "Map of GCS buckets to create. See modules/storage_bucket/README.md for the schema."
  type        = any
  default     = {}
}
