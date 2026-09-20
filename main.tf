provider "aws" {
  region = "ap-southeast-2"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # lets private-subnet instances reach the internet to pull the docker image
  enable_nat_gateway = true
  single_nat_gateway = true
}

data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_lb" "ha-infra" {
  name               = "ha-infra-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Name = "ha-infra-lb"
  }
}

resource "aws_lb_target_group" "ha-infra" {
  name     = "ha-infra-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "ha-infra-tg"
  }
}

resource "aws_lb_listener" "ha-infra" {
  load_balancer_arn = aws_lb.ha-infra.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ha-infra.arn
  }
}

resource "aws_security_group" "alb" {
  name        = "ha-infra-alb-sg"
  description = "Security group for the ha-infra ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ha-infra-alb-sg"
  }
}

resource "aws_security_group" "instance" {
  name        = "ha-infra-instance-sg"
  description = "Security group for ha-infra EC2 instances"
  vpc_id      = module.vpc.vpc_id

  # only the ALB can reach instances directly, not the public internet
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ha-infra-instance-sg"
  }
}

resource "aws_autoscaling_group" "ha-infra" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 2
  vpc_zone_identifier  = module.vpc.private_subnets
  launch_configuration = aws_launch_configuration.ha-infra.id

  # route traffic to ASG instances and let the ALB health check drive replacements
  target_group_arns         = [aws_lb_target_group.ha-infra.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "ha-infra"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "ha-infra-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.ha-infra.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}

resource "aws_launch_configuration" "ha-infra" {
  name            = "ha-infra-lc"
  image_id        = data.aws_ami.latest_amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install -y docker
              systemctl start docker
              systemctl enable docker

              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

              docker run -d --restart unless-stopped -p 80:${var.container_port} \
                -e INSTANCE_ID=$INSTANCE_ID \
                -e NG_ALLOWED_HOSTS=* \
                ${var.container_image}
            EOF

  lifecycle {
    create_before_destroy = true
  }
}