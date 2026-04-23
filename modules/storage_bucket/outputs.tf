###############################################################################
# Outputs — Standardized map-in / map-out pattern
###############################################################################

output "buckets" {
  description = "Map of bucket name to its attributes."
  value = {
    for name, bucket in google_storage_bucket.this : name => {
      id        = bucket.id
      name      = bucket.name
      url       = bucket.url
      self_link = bucket.self_link
      location  = bucket.location
      labels    = bucket.effective_labels
    }
  }
}

output "names" {
  description = "Map of bucket name to its name (convenience shorthand)."
  value = {
    for name, bucket in google_storage_bucket.this : name => bucket.name
  }
}

output "urls" {
  description = "Map of bucket name to its gs:// URL."
  value = {
    for name, bucket in google_storage_bucket.this : name => bucket.url
  }
}
