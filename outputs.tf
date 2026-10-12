output "alb_dns_name" {
  description = "Open this in a browser after apply."
  value       = aws_lb.web.dns_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "github_plan_role_arn" {
  description = "Put this in the repo variable AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.github_plan.arn
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.trail.id
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.main.id
}
