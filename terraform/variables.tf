variable "account_id" {
  description = "AWS account ID that hosts the site; providers refuse to run against any other account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "domain" {
  description = "Apex domain of the site; also the name of the Route 53 zone."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository (owner/name) whose main branch may assume the deploy role."
  type        = string
}

variable "records" {
  description = "Route 53 records, keyed by <fqdn>-<TYPE>. Each has either values or alias (a key of the alias targets in locals.tf)."
  type = map(object({
    values = optional(list(string))
    alias  = optional(string)
    ttl    = optional(number, 300)
  }))

  validation {
    condition     = alltrue([for r in var.records : (r.values != null) != (r.alias != null)])
    error_message = "Each record must set exactly one of values or alias, because Route 53 rejects a record that has both or neither."
  }

  validation {
    condition     = alltrue([for r in var.records : r.alias == null || contains(["site"], r.alias)])
    error_message = "Each record alias must be \"site\", the only alias target defined."
  }
}

variable "default_tags" {
  description = "Tags applied to every resource via the provider default_tags."
  type        = map(string)
  default     = { ManagedBy = "terraform" }
}
