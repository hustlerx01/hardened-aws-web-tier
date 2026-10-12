# Scanner results and accepted findings

Scanned 2026-10-11 with tfsec v1.28.11 and Trivy v0.75.0 (`trivy config .`). Terraform 1.9.8.

| Tool | Result |
|------|--------|
| `terraform fmt -check -recursive` | clean |
| `terraform validate` (`init -backend=false`) | Success |
| tfsec | 30 passed, 6 ignored, 0 open |
| Trivy config | 0 failures (89 checks passed, 1 ignored inline) |

## Accepted findings (each has an inline `#tfsec:ignore` / `#trivy:ignore` next to the resource)

| Check | Resource | Why it's accepted |
|-------|----------|-------------------|
| aws-elb-alb-not-public | `aws_lb.web` | It's the internet-facing entry point. Only the ALB is public; EC2 sits in private subnets with no public IP. |
| aws-ec2-no-public-ingress-sgr (x2) | `alb_http`, `alb_https` | A public web ALB has to accept 80/443 from anywhere. Port 80 only redirects to 443 once a cert is set. |
| aws-ec2-no-public-egress-sgr | `web_https_out` | EC2 needs HTTPS out through NAT for dnf security updates and SSM. Limited to port 443. A tighter option is VPC endpoints for SSM plus an S3 gateway endpoint for the dnf repos, which costs more for a lab. |
| aws-elb-http-not-used | `aws_lb_listener.http` | It redirects (301) to HTTPS whenever `acm_certificate_arn` is set. Lab mode with no domain/cert serves HTTP. **Set a cert for anything real.** |
| aws-iam-no-policy-wildcards | `github_plan`, `flow`, `trail_cw` | `Describe*`/`List*` APIs don't support resource-level permissions, so `Resource "*"` is the only option. Every action is read-only. The logs policies use `<log-group-arn>:*` because log streams are created on the fly; each is scoped to a single log group. |
| aws-s3-enable-bucket-logging / AVD-AWS-0089 | `aws_s3_bucket.trail` | Server access logging on the CloudTrail bucket needs a second log bucket. CloudTrail already records the API calls; S3 data events would cover reads. Deferred to keep the lab small. |

## Hardening that *is* in place
IMDSv2 required (hop limit 1), encrypted EBS with a CMK, no SSH or key pair (SSM only), `drop_invalid_header_fields` on the ALB, TLS 1.3 policy on the HTTPS listener, VPC flow logs, a locked-down default SG, KMS key rotation, CloudTrail (multi-region, log file validation, KMS, CloudWatch), a trail bucket with public access block + BucketOwnerEnforced + versioning + TLS-only policy, GuardDuty with S3 protection, an OIDC role limited to one repo/branch + same-repo PRs with read-only permissions, and Nginx with `server_tokens off`, security headers and `limit_req`.
