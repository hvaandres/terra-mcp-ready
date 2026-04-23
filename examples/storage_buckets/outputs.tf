output "buckets" {
  description = "All bucket attributes."
  value       = module.storage_buckets.buckets
}

output "bucket_urls" {
  description = "Map of bucket name to gs:// URL."
  value       = module.storage_buckets.urls
}
