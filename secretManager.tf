resource "random_string" "secret_suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "my-app-secret-${random_string.secret_suffix.result}"
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
    secret_string = jsonencode({
        username = "admin"
        password = "password123"
    })
}

