resource "aws_vpc" "vpc" {
   cidr_block = "10.0.0.0/16"

   enable_dns_hostnames = true 
   enable_dns_support = true
   
   tags ={
    Name = "vpc"
    environment ="dev"
   }
}

resource "aws_subnet" "public_subnet" {
   vpc_id = aws_vpc.vpc.id 
   cidr_block = "10.0.1.0/24"
   map_public_ip_on_launch = true 
   tags = {
     Name = "public_subnets"
   }
}

resource "aws_subnet" "private_subnet" {
     vpc_id = aws_vpc.vpc.id 
     cidr_block =  "10.0.2.0/24"
  
  tags = {
    Name = "private_subnets"
  }
}


resource "aws_route_table" "public_route_table" {
   vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "private_route_table" {
   vpc_id = aws_vpc.vpc.id 
}

resource "aws_route_table_association" "public_route_table_ass" {
    route_table_id = aws_route_table.public_route_table.id 
    subnet_id = aws_subnet.public_subnet.id 
}

resource "aws_route_table_association" "private_route_table_ass" {
    route_table_id = aws_route_table.private_route_table.id 
    subnet_id = aws_subnet.private_subnet.id
}

resource "aws_internet_gateway" "IG" {
  vpc_id = aws_vpc.vpc.id 
  tags = {
    Name = "Internet_gateway"
  }
}


resource "aws_route" "public_route" {
    route_table_id = aws_route_table.public_route_table.id 
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IG.id
}

resource "aws_eip" "eip" {
  domain =  "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  subnet_id = aws_subnet.public_subnet.id 
  allocation_id = aws_eip.eip.id 
}

resource "aws_route" "private_route" {
    route_table_id = aws_route_table.private_route_table.id 
     destination_cidr_block = "0.0.0.0/0"
     nat_gateway_id = aws_nat_gateway.nat_gw.id 
}