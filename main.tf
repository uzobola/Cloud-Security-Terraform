# Provider configuration
# Security Note: AWS provider should ideally be configured with assumed roles and MFA
# for production environments
provider "aws" {
  region = "us-east-1"
}

# VPC Configuration
# Security Best Practice: Isolated network environment with private IP space
# This prevents direct internet accessibility to resources unless explicitly configured
resource "aws_vpc" "microblog_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true  # Required for internal DNS resolution
  enable_dns_support   = true  # Enables internal domain name resolution

  tags = {
    Name = "microblog-vpc"
  }
}

# Public Subnet Configuration for each availability zone
# Security Note: Only resources that MUST be internet-facing should be placed here
# Examples: Load balancers, bastion hosts, NAT gateways
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.microblog_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true  # Security consideration: Only enable for resources requiring direct internet access
  availability_zone       = "us-east-1a"

  tags = {
    Name = "microblog-public-subnet-1"
  }
}

# Private Subnet Configuration for each availability zone
# Security Best Practice: Place application servers and databases in private subnets
# This provides an additional layer of network security
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.microblog_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "microblog-private-subnet-1"
  }
}

# Internet Gateway
# Security Note: Single point of egress/ingress for the VPC
# All internet traffic is monitored and controlled through this gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.microblog_vpc.id

  tags = {
    Name = "microblog-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "microblog-nat-eip"
  }
}

# NAT Gateway for private subnets
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "microblog-nat"
  }
}


# Route Table Configuration
# Security Best Practice: Separate route tables for public and private subnets
# This ensures private resources cannot directly access the internet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.microblog_vpc.id

  tags = {
    Name = "microblog-public-rt"
  }
}

# Public Route Configuration
# Security Note: Only public subnets should have a route to the internet gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Public Route Table Association. Should be made for both AZ's
# Links the public subnet to the route table with internet access
resource "aws_route_table_association" "public_rt_assoc_1" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


# Private Route Configuration
# Security Note: Should live in the public subnets 
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.microblog_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "microblog-private-rt"
  }
}

# Private Route Table Association. Should be made for both AZ's
# Links the private subnets
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}


# Security Group Configuration
# Security Best Practice: Implement the principle of least privilege
# Only necessary ports are opened, and access is restricted to specific CIDR blocks
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security group for web servers with hardened rules"
  vpc_id      = aws_vpc.microblog_vpc.id

  # SSH Access Configuration
  # Security Hardening: SSH access restricted to internal admin network
  # This prevents unauthorized access attempts from the public internet
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"]  # Restricted to internal admin subnet
    description = "SSH access from internal admin network"
  }

  # HTTPS Configuration
  # Security Best Practice: Use HTTPS for encrypted data transmission
  # All sensitive web traffic should be encrypted using TLS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access - encrypted web traffic"
  }

  # HTTP Configuration
  # Security Note: HTTP is only allowed for initial connections
  # Should be configured to redirect to HTTPS

  # Old (insecure)
  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  #   description = "HTTP access - should redirect to HTTPS"
  # }

  # Application Port Configuration
  # Security Hardening: Internal application port access restricted to VPC
  # Prevents direct external access to application layer
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Flask application port - VPC internal only"
  }

  # Egress Rules Configuration
  # Security Best Practice: Implement strict egress rules
  # Only allow necessary outbound traffic based on application requirements
  
  # HTTP Outbound
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound - for package updates and external services"
  }

  # HTTPS Outbound
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound - for secure external communication"
  }

  # DNS Resolution
  # Security Note: Required for domain name resolution
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS resolution - required for domain name resolution"
  }

  tags = {
    Name = "microblog-web-sg"
  }
}

# EC2 Instance Configuration
# Security Best Practice: Implement multiple security layers
resource "aws_instance" "web" {
  ami                         = "ami-0866a3c8686eaeeba"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  # Security Note: User data scripts should be reviewed for security best practices
  user_data = file("blog.sh")

  # Security Best Practice: Enable EBS encryption
  # This ensures data at rest is encrypted
  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "MicroblogApp"
  }

  depends_on = [aws_security_group.web_sg]
}
