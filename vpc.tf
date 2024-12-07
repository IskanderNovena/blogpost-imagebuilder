module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16.0"

  name = "${var.name}-vpc"
  cidr = var.vpc_cidr

  azs = data.aws_availability_zones.available.names
  #   private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 101),
    cidrsubnet(var.vpc_cidr, 8, 102),
    cidrsubnet(var.vpc_cidr, 8, 103),
  ]
  map_public_ip_on_launch = true

  enable_nat_gateway = false
  enable_vpn_gateway = false
}

resource "aws_security_group" "imagebuilder_instances" {
  name        = "imagebuilder-instances"
  description = "Allow outbound traffic for Image Builder instances"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.imagebuilder_instances.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.imagebuilder_instances.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
