###############################################################################
# Outputs — Standardized map-in / map-out pattern
#
# Every module in this repo returns a map keyed by the same keys the consumer
# provided, making it straightforward to reference downstream.
###############################################################################

output "projects" {
  description = "Map of project_id to its attributes."
  value = {
    for project_id, project in google_project.this : project_id => {
      id         = project.id
      project_id = project.project_id
      number     = project.number
      name       = project.name
      labels     = project.effective_labels
    }
  }
}

output "ids" {
  description = "Map of project_id to its fully-qualified resource ID (convenience shorthand)."
  value = {
    for project_id, project in google_project.this : project_id => project.id
  }
}

output "numbers" {
  description = "Map of project_id to its GCP project number (useful for IAM bindings and APIs that require the numeric form)."
  value = {
    for project_id, project in google_project.this : project_id => project.number
  }
}
