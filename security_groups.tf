resource "aws_security_group" "alb" {
  name        = "${var.project}-alb"
  description = "Internet-facing ALB: 80/443 in, only to web tier out"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet (redirected to HTTPS when a cert is set)"
  cidr_ipv4         = "0.0.0.0/0" #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
  cidr_ipv4         = "0.0.0.0/0" #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to Nginx on web tier only"
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "web" {
  name        = "${var.project}-web"
  description = "Web tier: only ALB in; HTTPS out via NAT for package updates"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  description                  = "HTTP from ALB security group only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_https_out" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS out through NAT for dnf repos and SSM"
  cidr_ipv4         = "0.0.0.0/0" #tfsec:ignore:aws-ec2-no-public-egress-sgr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
