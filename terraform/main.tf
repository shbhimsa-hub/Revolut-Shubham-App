provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "remote"
  region = "eu-west-1"
}

data "aws_availability_zones" "available" {}

data "aws_ssm_parameter" "ubuntu_ami_remote" {
  provider = aws.remote
  name     = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# VPC Peering between main and remote
resource "aws_vpc_peering_connection" "cross_region" {
  vpc_id        = aws_vpc.main.id
  peer_vpc_id   = aws_vpc.remote.id
  peer_region   = "eu-west-1"
  auto_accept   = false

  tags = {
    Name = "central-west-peering"
  }
}

resource "aws_vpc_peering_connection_accepter" "remote_accept" {
  provider                  = aws.remote
  vpc_peering_connection_id = aws_vpc_peering_connection.cross_region.id
  auto_accept               = true

  tags = {
    Name = "accept-central-west"
  }
}

resource "aws_route" "to_remote_vpc" {
  route_table_id              = aws_route_table.rt.id
  destination_cidr_block      = "10.1.0.0/16"
  vpc_peering_connection_id   = aws_vpc_peering_connection.cross_region.id
}

resource "aws_route" "to_central_vpc" {
  provider                    = aws.remote
  route_table_id              = aws_route_table.remote_rt.id
  destination_cidr_block      = "10.0.0.0/16"
  vpc_peering_connection_id   = aws_vpc_peering_connection.cross_region.id
}

# VPC in primary region
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet("10.0.1.0/24", 2, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-${count.index}" }
}

resource "aws_route_table_association" "rta" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "postgres_ha_remote" {
  provider    = aws.remote
  name        = "postgres_ha_sg_remote"
  description = "Allow PostgreSQL, SSH, Patroni, etcd (remote)"
  vpc_id      = aws_vpc.remote.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "10.1.0.0/16"]
  }

  ingress {
    from_port   = 8008
    to_port     = 8008
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "10.1.0.0/16"]
  }

  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "10.1.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "postgres_ha_sg_remote"
  }
}

resource "aws_security_group" "postgres_ha" {
  name        = "postgres_ha_sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow PostgreSQL, SSH, Patroni, etcd"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0", "10.0.0.0/16", "10.1.0.0/16"]
  }

  ingress {
    from_port   = 8008
    to_port     = 8008
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "10.1.0.0/16"]
  }

  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "10.1.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "postgres_ha_sg" }
}

resource "aws_instance" "db_nodes" {
  count                       = 3
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[count.index].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.postgres_ha.id]
  key_name                    = var.key_name
  tags = { Name = "db${count.index + 1}" }
}

# VPC in remote region
resource "aws_vpc" "remote" {
  provider = aws.remote
  cidr_block = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "remote-vpc" }
}

resource "aws_internet_gateway" "remote_igw" {
  provider = aws.remote
  vpc_id   = aws_vpc.remote.id
}

resource "aws_route_table" "remote_rt" {
  provider = aws.remote
  vpc_id   = aws_vpc.remote.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.remote_igw.id
  }
}

resource "aws_subnet" "db4_subnet" {
  provider                = aws.remote
  vpc_id                  = aws_vpc.remote.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = var.db4_az
  map_public_ip_on_launch = true
  tags = { Name = "db4-subnet" }
}

resource "aws_route_table_association" "remote_rta" {
  provider       = aws.remote
  subnet_id      = aws_subnet.db4_subnet.id
  route_table_id = aws_route_table.remote_rt.id
}

resource "aws_instance" "db4" {
  provider                  = aws.remote
  ami                       = data.aws_ssm_parameter.ubuntu_ami_remote.value
  instance_type             = var.instance_type
  availability_zone         = var.db4_az
  subnet_id                 = aws_subnet.db4_subnet.id
  key_name                  = var.key_name
  associate_public_ip_address = true
  private_ip                = var.db4_private_ip
  vpc_security_group_ids    = [aws_security_group.postgres_ha_remote.id]
  tags = { Name = "db4" }
}
