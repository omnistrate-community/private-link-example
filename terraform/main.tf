provider "aws" {
  region = "{{ $sys.deploymentCell.region }}"
}

# Create a security group for the load balancer with port 5432 opened
resource "aws_security_group" "nlb_sg" {
  name        = "nlb-security-group"
  description = "Security group for NLB"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow from any IP. Adjust the range for more security.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a target group for port 5432
resource "aws_lb_target_group" "ps_target_group" {
  name     = "postgres-target-group"
  port     = 5432
  protocol = "TCP"
  vpc_id   = "{{ $sys.deploymentCell.cloudProviderNetworkID }}"

  health_check {
    port                = "5432"
    protocol            = "TCP"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create a network load balancer
resource "aws_lb" "ps_lb" {
  name               = "postgres-nlb"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.nlb_sg.id]

  subnets = [
    "{{ $sys.deploymentCell.privateSubnetIDs[0].id }}",
    "{{ $sys.deploymentCell.privateSubnetIDs[1].id }}",
    "{{ $sys.deploymentCell.privateSubnetIDs[2].id }}"
  ]

  enable_deletion_protection = false
}

# Create a listener for the NLB
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.ps_lb.arn
  port              = 5432
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ps_target_group.arn
  }
}

# Create a VPC Endpoint Service
resource "aws_vpc_endpoint_service" "pg_vpc_endpoint_service" {
  acceptance_required         = false  # Auto-approve endpoint connections
  network_load_balancer_arns  = [aws_lb.ps_lb.arn]  # Reference to the NLB
  allowed_principals          = ["arn:aws:iam::{{ $var.connectAccountID }}:root"]

  tags = {
    Name = "PostgresVPCEndpointService"
  }
}

# Output the VPC Endpoint Service name
output "vpc_endpoint_service_name" {
  description = "The name of the VPC Endpoint Service"
  value       = aws_vpc_endpoint_service.pg_vpc_endpoint_service.service_name
}

# Output the VPC Endpoint Service DNS name if applicable
output "vpc_endpoint_service_dns_name" {
  description = "The DNS name of the VPC Endpoint Service"
  value       = aws_vpc_endpoint_service.pg_vpc_endpoint_service.base_endpoint_dns_names
}

# Output the Target Group ARN
output "target_group_arn" {
  description = "The ARN of the Target Group"
  value       = aws_lb_target_group.ps_target_group.arn
}