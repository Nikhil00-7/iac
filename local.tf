locals {
  db_cred = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string)
}
