terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  required_version = ">= 1.5.0"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "linux2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  db_port = var.db_engine == "aurora-postgresql" ? 5432 : 3306

  alb_https_enabled = var.enable_https && var.alb_certificate_arn != ""

  common_tags = merge(
    var.tags,
    {
      Name = var.project_name
    }
  )
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.common_tags
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = local.common_tags
}

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-${local.azs[count.index]}"
  })
}

resource "aws_subnet" "app" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.app_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-app-${local.azs[count.index]}"
  })
}

resource "aws_subnet" "db" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-${local.azs[count.index]}"
  })
}

resource "aws_eip" "nat" {
  count = length(local.azs)
  vpc   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip-${local.azs[count.index]}"
  })
}

resource "aws_nat_gateway" "nat" {
  count          = length(local.azs)
  allocation_id  = aws_eip.nat[count.index].id
  subnet_id      = aws_subnet.public[count.index].id
  depends_on     = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-${local.azs[count.index]}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table" "private" {
  count  = length(local.azs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt-${local.azs[count.index]}"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "db" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Internet-facing ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the internet"
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from the internet"
    from_port   = var.https_port
    to_port     = var.https_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Web tier EC2 security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Traffic from ALB"
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-web-sg"
  })
}

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Application tier security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "App traffic from web tier"
    from_port        = var.app_port
    to_port          = var.app_port
    protocol         = "tcp"
    security_groups  = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-app-sg"
  })
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Database tier security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "Database access from app tier"
    from_port        = local.db_port
    to_port          = local.db_port
    protocol         = "tcp"
    security_groups  = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-sg"
  })
}

resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = local.common_tags
}

resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-web-tg"
  port        = var.http_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "https" {
  count             = local.alb_https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.alb.arn
  port              = var.https_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web-"
  image_id      = data.aws_ami.linux2.id
  instance_type = var.web_instance_type
  monitoring {
    enabled = true
  }

  network_interfaces {
    device_index              = 0
    associate_public_ip_address = true
    security_groups           = [aws_security_group.web.id]
  }

  user_data = base64encode(<<-EOF
                #!/bin/bash
                yum update -y
                yum install -y httpd
                systemctl enable httpd
                systemctl start httpd
                echo "Web tier instance from ${var.project_name}" > /var/www/html/index.html
                EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(local.common_tags, {
      Name = "${var.project_name}-web-instance"
    })
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-app-"
  image_id      = data.aws_ami.linux2.id
  instance_type = var.app_instance_type
  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
                #!/bin/bash
                yum update -y
                yum install -y httpd
                systemctl enable httpd
                systemctl start httpd
                echo "App tier instance from ${var.project_name}" > /var/www/html/index.html
                EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(local.common_tags, {
      Name = "${var.project_name}-app-instance"
    })
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${var.project_name}-web-asg"
  desired_capacity          = var.web_desired_capacity
  min_size                  = var.web_min_size
  max_size                  = var.web_max_size
  vpc_zone_identifier       = aws_subnet.public[*].id
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "web"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-app-asg"
  desired_capacity          = var.app_desired_capacity
  min_size                  = var.app_min_size
  max_size                  = var.app_max_size
  vpc_zone_identifier       = aws_subnet.app[*].id
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  health_check_type         = "EC2"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "app"
    propagate_at_launch = true
  }
}

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${var.project_name}-cluster"
  engine                  = var.db_engine
  engine_version          = var.db_engine_version
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.aurora.id
  vpc_security_group_ids  = [aws_security_group.db.id]
  backup_retention_period = var.db_backup_retention_period
  preferred_backup_window = var.db_backup_window
  storage_encrypted       = true
  skip_final_snapshot     = true

  tags = local.common_tags
}

resource "aws_rds_cluster_instance" "aurora" {
  count              = 2
  identifier         = "${var.project_name}-db-${count.index == 0 ? "writer" : "reader"}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = var.db_engine_version
  db_subnet_group_name = aws_db_subnet_group.aurora.id
  publicly_accessible  = false
  promotion_tier       = count.index
  availability_zone    = local.azs[count.index]

  tags = local.common_tags
}
