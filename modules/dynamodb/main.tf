terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.92"
    }
  }
}

resource "aws_dynamodb_table" "main" {
  count        = length(var.create_dynamodb_config)
  name         = var.create_dynamodb_config[count.index].table_name
  billing_mode = var.create_dynamodb_config[count.index].billing_mode
  hash_key     = var.create_dynamodb_config[count.index].hash_key
  range_key    = var.create_dynamodb_config[count.index].range_key
  attribute {
    name = var.create_dynamodb_config[count.index].hash_key
    type = "S"
  }

  attribute {
    name = var.create_dynamodb_config[count.index].range_key
    type = "S"
  }

  dynamic "attribute" {
    for_each = var.create_dynamodb_config[count.index].global_secondary_indexes
    content {
      name = attribute.value.name
      type = "S"
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.create_dynamodb_config[count.index].global_secondary_indexes
    content {
      name            = global_secondary_index.value.hash_key
      hash_key        = global_secondary_index.value.name
      projection_type = "ALL"
    }
  }

  # Enable point-in-time recovery (recommended for production)
  point_in_time_recovery {
    enabled = var.create_dynamodb_config[count.index].enable_pitr
  }

  # Enable encryption at rest
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = var.create_dynamodb_config[count.index].table_name
  }
}
