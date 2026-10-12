# SPEC: hardened-aws-web-tier

## Goal
A small AWS web tier in Terraform where every choice is a security choice I can explain. Only the load balancer is public, the servers sit in private subnets with no public IPs, CI uses OIDC instead of access keys, and CloudTrail + GuardDuty are on from day one. Scanners in CI keep it that way.

## Scope (1-3 days)
In: VPC (2 AZ), public subnets (ALB, NAT), private subnets (EC2 ASG), Nginx reverse proxy via user_data, least-privilege SGs, a GitHub OIDC role with read-only plan permissions, CloudTrail, GuardDuty, flow logs, CI with fmt/validate/tfsec/Trivy and a guarded plan job.
Out: a real domain, RDS, WAF, multi-account setup, apply from CI.

## Architecture
```
Internet ─► ALB (public subnets, SG: 80/443 from 0.0.0.0/0)
              │  SG egress: port 80 → web SG only
              ▼
          EC2 ASG (private subnets, no public IP, IMDSv2, SSM only, no SSH)
          Nginx :80 → 127.0.0.1:8080 app
              │  egress 443 only
              ▼
          NAT GW (public subnet) ─► internet (dnf updates, SSM)

CloudTrail (all regions, log validation) ─► S3 (KMS, public access block, TLS-only) + CloudWatch
GuardDuty detector + S3 protection        VPC flow logs ─► CloudWatch (KMS)
GitHub Actions ─OIDC─► IAM role (repo:hustlerx01/hardened-aws-web-tier:ref:refs/heads/main | pull_request) ─► read-only plan
```

## Threat model (short)
| Threat | Control |
|--------|---------|
| Direct attack on web servers | No public IP; SG allows only the ALB SG on port 80 |
| SSH brute force / leaked keys | No port 22, no key pair; access is through SSM Session Manager (logged in CloudTrail) |
| SSRF → instance credentials theft | IMDSv2 required, hop limit 1 |
| Leaked CI credentials | No static keys; OIDC role bound to one repo and branch, 1-hour sessions, read-only |
| Attacker covers tracks | Multi-region CloudTrail with log file validation, versioned KMS-encrypted bucket |
| Compromise goes unnoticed | GuardDuty, VPC flow logs |
| Request smuggling / header abuse | ALB `drop_invalid_header_fields`, Nginx `limit_req`, 1 MB body cap |
| Misconfig drift | tfsec + Trivy fail CI on new findings |

## Day-by-day
- Day 1: read every file and run `terraform fmt/validate`, tfsec and trivy locally. Push and get CI green. Draw the architecture diagram (draw.io) → `docs/architecture.png`.
- Day 2: set a $5 budget alert, then `terraform apply` in a personal account. Curl the ALB and screenshot the Nginx page. Try reaching an instance directly (it should fail). Open an SSM session. Check that CloudTrail shows the `StartSession` event. Generate GuardDuty sample findings. Screenshot everything, then `terraform destroy`.
- Day 3 (optional): add the S3 backend, set `AWS_PLAN_ROLE_ARN`, and get one green OIDC plan run in Actions. Then swap NAT egress for VPC endpoints and write down the cost difference.

## Acceptance checks
- [ ] `terraform fmt -check -recursive` clean
- [ ] `terraform init -backend=false && terraform validate` succeeds
- [ ] tfsec: 0 open findings; every ignore has a reason in SECURITY_FINDINGS.md
- [ ] `trivy config .`: 0 failures
- [ ] After apply: ALB URL returns the Nginx page; instances have no public IP (`aws ec2 describe-instances` screenshot)
- [ ] CloudTrail shows `IsMultiRegionTrail: true`, `LogFileValidationEnabled: true`
- [ ] Destroy leaves nothing billable (check NAT/EIP/ALB consoles)

## Recruiter can verify in 30s
1. **README top**: green `terraform-ci` badge. Click it to see fmt, validate, tfsec and Trivy all passing.
2. **README "Screenshots"**: architecture diagram + ALB page + "instance has no public IP" (placeholders `docs/architecture.png`, `docs/alb.png`, `docs/no-public-ip.png` until recorded).
3. **SECURITY_FINDINGS.md**: the scanner numbers and why each accepted finding is accepted.
4. **iam_github_oidc.tf**: the `sub` condition pins the role to this repo, with no static keys anywhere.
