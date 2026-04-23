output "projects" {
  description = "All project attributes."
  value       = module.projects.projects
}

output "project_ids" {
  description = "Project resource IDs."
  value       = module.projects.ids
}

output "project_numbers" {
  description = "Project numbers (for IAM and APIs)."
  value       = module.projects.numbers
}
