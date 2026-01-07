variable "create_dynamodb_config" {
  description = "configuration for the creation of dynamodb table"
  type = list(object({
    table_name   = string
    hash_key     = string
    range_key    = string
    enable_pitr  = bool
    billing_mode = string
    global_secondary_indexes = optional(
      list(object({
        name     = string
        hash_key = string
        type     = string
      })), []
    )
  }))
  nullable = false
}
