# Single-table design (see aws/src/repository.py): GAME#/META, GAME#/PLAYER#,
# and CONN# items. TTL auto-expires abandoned games and connections.
resource "aws_dynamodb_table" "games" {
  name         = "${var.project_name}-games"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.tags
}
