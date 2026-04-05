resource "aws_db_instance" "db" {
    db_name = "todo_db"
    allocated_storage = 20 
    engine= "mysql"
    engine_version = "8.0"
    instance_class = "db.t3.micro"
    username = local.db_cred.username
    password = local.db_cred.password
    skip_final_snapshot = true 
    multi_az = false
    vpc_security_group_ids = [aws_security_group.rds_sg.id]  
    db_subnet_group_name = aws_db_subnet_group.db_subnet.name 
}

resource "aws_db_subnet_group" "db_subnet" {
  name = "my-db-subnet-group"
  subnet_ids =aws_subnet.private_subnet[*].id 

  tags ={
    Name = "my-db-subnet-group"
  }
}

  

  # outputs.tf

output "rds_endpoint" {
  description = "RDS MySQL Endpoint (copy this after terraform apply)"
  value       = aws_db_instance.db.endpoint
}

output "rds_address" {
  description = "RDS Hostname only (without port)"
  value       = aws_db_instance.db.address
}

output "db_username" {
  description = "Database username"
  value       = local.db_cred.username
  sensitive   = true
}

output "db_name" {
  description = "Database name to use"
  value       = "todo_db"   
}