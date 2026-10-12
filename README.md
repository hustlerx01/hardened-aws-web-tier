# hardened-aws-web-tier

![terraform-ci](https://github.com/hustlerx01/hardened-aws-web-tier/actions/workflows/ci.yml/badge.svg)

Terraform for a small AWS web tier with security as the starting point. Only the load balancer faces the internet. The web servers run Nginx in private subnets with no public IP, and you get on them through SSM instead of SSH. CloudTrail and GuardDuty are on, and GitHub Actions authenticates with OIDC, so there are no AWS keys in the repo or in secrets.

## What's in it
| File | What it sets up |
|------|-----------------|
| `vpc.tf` | VPC across 2 AZs, public + private subnets, NAT, flow logs |
| `security_groups.tf` | ALB takes 80/443; EC2 takes port 80 from the ALB's security group only |
| `alb.tf` | ALB, HTTPS listener with TLS 1.3 policy (when you give a cert), HTTP→HTTPS redirect |
| `ec2.tf`, `user_data.sh` | Launch template (IMDSv2, encrypted disk, no SSH key) + Auto Scaling group; Nginx reverse proxy |
| `iam_github_oidc.tf` | OIDC provider + read-only plan role that only this repo's `main` branch and PRs can assume |
| `cloudtrail.tf` | Multi-region trail, log file validation, KMS-encrypted S3 bucket with public access block |
| `guardduty.tf` | GuardDuty detector with S3 protection |
| `kms.tf` | One customer-managed key with rotation |

## Run the checks locally (no AWS account needed)
```bash
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
tfsec .
trivy config .
```
```bash
pip install -r requirements-dev.txt && pytest -q   # 9 tests: parse the .tf files and check IMDSv2, no public IP, encrypted EBS, SG-only ingress, TLS 1.3, CloudTrail, S3 public access block, KMS rotation, OIDC scope (+ tfsec if installed)
```
Current results and accepted findings: [SECURITY_FINDINGS.md](SECURITY_FINDINGS.md).

## Deploy (costs money, so tear it down the same day)
Read [COST_AND_TEARDOWN.md](COST_AND_TEARDOWN.md) first. The NAT gateway is the main cost.
```bash
cp terraform.tfvars.example terraform.tfvars   # edit github_repo, region
terraform init && terraform apply
curl http://$(terraform output -raw alb_dns_name)
terraform destroy
```

## CI
`static` job: fmt, validate, tfsec, Trivy. Needs no secrets.
`plan` job: runs only once the repo variable `AWS_PLAN_ROLE_ARN` is set (from `terraform output github_plan_role_arn`). It assumes the role through OIDC and runs `terraform plan`.

## Screenshots
No screenshots yet. This stack has only been scanned statically (see Results); an architecture diagram, the Nginx page through the ALB and `describe-instances` output showing no public IP need a real AWS deploy and will be added after one.

## Results
Static scan run 2026-10-12 (tfsec v1.28.14, Trivy 0.75.0, Terraform v1.9.8), using the commands above on the repo root:
- `terraform fmt -check` / `terraform validate`: clean
- tfsec: 30 checks passed, 0 open (critical 0 / high 0 / medium 0 / low 0), 6 accepted with reasons (inline `tfsec:ignore`, see SECURITY_FINDINGS.md)
- Trivy (`trivy config .`): 0 misconfigurations
- Resources created per apply: not measured yet. To get it, run `terraform plan` and read the "N to add" line.
- Cost of one apply/test/destroy session: not measured yet. To get it, check AWS Cost Explorer for the day of the session (see COST_AND_TEARDOWN.md).

## Resume bullet
> Deployed a two-AZ AWS web tier with zero public-IP servers, zero static CI keys and 0 open tfsec/Trivy findings across 30 passing tfsec checks, by writing Terraform for a private-subnet Nginx tier behind an ALB, least-privilege security groups, a repo-scoped GitHub OIDC role, multi-region CloudTrail and GuardDuty, gated by a CI pipeline that fails on new misconfigurations.
