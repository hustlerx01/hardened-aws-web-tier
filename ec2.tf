data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Instance role: SSM Session Manager only (no SSH keys, no port 22).
resource "aws_iam_role" "web" {
  name = "${var.project}-web"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project}-web"
  role = aws_iam_role.web.name
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project}-web-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type
  user_data     = base64encode(templatefile("${path.module}/user_data.sh", { project = var.project }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.web.arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.web.id]
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      volume_type = "gp3"
      encrypted   = true
      kms_key_id  = aws_kms_key.logs.arn
    }
  }

  monitoring {
    enabled = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "${var.project}-web"
  min_size            = var.web_instance_count
  max_size            = var.web_instance_count
  desired_capacity    = var.web_instance_count
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-web"
    propagate_at_launch = true
  }
}
