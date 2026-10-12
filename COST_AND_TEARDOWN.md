# Cost and teardown

Rough ap-south-1 on-demand prices. Check the AWS pricing page before you apply. [CONFIRM]

| Item | Approx. cost | Note |
|------|--------------|------|
| NAT Gateway (1) | ~$0.056/hr + data | **The biggest cost.** About $1.35/day. `single_nat_gateway = false` doubles it. |
| ALB | ~$0.02/hr + LCU | ~$0.5/day |
| 2 × t3.micro | free tier 750 h/month for 12 months, otherwise ~$0.011/hr each | |
| KMS CMK | $1/month (prorated) | |
| CloudTrail | first management trail free; S3 + CloudWatch Logs ingestion small | |
| GuardDuty | 30-day free trial, then usage-based | |
| VPC flow logs | CloudWatch ingestion ~$0.5/GB | |

**Plan: apply, test, screenshot, destroy in the same session.** A 2-hour session should cost well under $1. [CONFIRM after first run]

## Teardown
```bash
terraform destroy
```
Then check manually:
- The KMS key goes into a 7-day "pending deletion" state. That's expected.
- CloudWatch log groups are deleted by Terraform.
- The trail bucket has `force_destroy = true`, so it is emptied and deleted.
- GuardDuty: the detector is deleted. If you enabled it before this lab in that region, `terraform import` it instead of creating a new one.
- If `create_github_oidc_provider = true` and other repos use the provider, destroy will remove it. Set it to false in that case.
- Set an AWS Budget alert of $5 before the first apply.
