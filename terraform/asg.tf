locals {
  solution_name = "ll-s3-gateway"
}

resource "aws_security_group" "this" {
  name        = "${local.solution_name}-${random_id.this.hex}"
  description = "${local.solution_name}-${random_id.this.hex}"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.this.id
}

resource "aws_security_group_rule" "ingress" {
  type        = "ingress"
  from_port   = 8000
  to_port     = 8000
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.this.id
}

resource "aws_lb" "this" {
  name               = "${local.solution_name}-${random_id.this.hex}"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false
}

resource "aws_lb_listener" "s3" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = resource.aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.s3.arn
  }
}

resource "aws_lb_target_group" "s3" {
  name     = "${local.solution_name}-s3-tg-${random_id.this.hex}"
  port     = 8000
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    protocol            = "HTTP"
    path = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }
}

resource "aws_launch_template" "this" {
  name_prefix                          = "${local.solution_name}-${random_id.this.hex}"
  image_id                             = var.ami_id
  instance_type                        = var.instance_type
  user_data                            = filebase64("${path.module}/resources/bootstrap.sh")
  vpc_security_group_ids               = [aws_security_group.this.id]
  instance_initiated_shutdown_behavior = "terminate"

  // uncomment this block and the IAM resources below to enable IAM permissions on the instances
  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  ebs_optimized = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }
}

resource "aws_autoscaling_group" "this" {
  name_prefix               = local.solution_name
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_grace_period = 1200
  health_check_type         = "ELB"
  target_group_arns         = [aws_lb_target_group.s3.arn]

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.this.id
        version            = "$Latest"
      }
      override {
        instance_type     = "c5a.xlarge"
        weighted_capacity = "3"
      }

      override {
        instance_type     = "c6i.xlarge"
        weighted_capacity = "2"
      }

      override {
        instance_type     = "c4.xlarge"
        weighted_capacity = "1"
      }
    }
    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 0
    }
  }
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.solution_name}-${random_id.this.hex}-instance-profile"
  role = aws_iam_role.this.id
}

resource "aws_iam_role" "this" {
  name = "${local.solution_name}-${random_id.this.hex}-iamrole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
    },
    "Effect": "Allow",
    "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "this" {
  name   = "${local.solution_name}-${random_id.this.hex}-iampolicy"
  role   = aws_iam_role.this.id
  policy = <<EOF
{
  "Version": "2012-10-17",	
  "Statement": [	
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetInstanceProfile",
        "iam:GetUser",
        "iam:GetRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
        "ssm:UpdateInstanceInformation",
        "ssm:UpdateInstanceAssociationStatus",
        "ssm:ListInstanceAssociations",
        "ec2messages:GetMessages"
      ],
      "Resource": "*"
    }
  ]
}
EOF

}
