data "aws_availability_zones" "multi_zone"{}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "vpc"
    environment = "dev"
  }
}

resource "aws_subnet" "public_subnet" {
  count  = 2 
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8 , count.index)
  availability_zone = data.aws_availability_zones.multi_zone.names[count.index]

  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnets"
  }
}

resource "aws_subnet" "private_subnet" {
  count  = 2
  vpc_id     = aws_vpc.vpc.id
  cidr_block = cidrsubnet(aws_vpc.vpc.cidr_block , 8 , count.index+2)
  availability_zone = data.aws_availability_zones.multi_zone.names[count.index]
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
  count = 2 
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet[count.index].id
}

resource "aws_route_table_association" "private_route_table_ass" {
  count = 2
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet[count.index].id
}

resource "aws_internet_gateway" "IG" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Internet_gateway"
  }
}


resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.IG.id
}

resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  count = 2
  subnet_id     = aws_subnet.public_subnet[count.index].id
  allocation_id = aws_eip.eip.id
}

resource "aws_route" "private_route" {
  count = 2
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
}