"""Static checks that the hardening claimed in README/SECURITY_FINDINGS is really in the Terraform.
Parses the .tf files with python-hcl2; no AWS account or terraform binary needed."""
import json, pathlib, shutil, subprocess
import hcl2
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def resources():
    out = {}
    for tf in ROOT.glob("*.tf"):
        with tf.open() as f:
            for block in hcl2.load(f).get("resource", []):
                for rtype, items in block.items():
                    for name, body in items.items():
                        out[(rtype, name)] = body
    return out


R = resources()


def of_type(t):
    return [b for (rt, _), b in R.items() if rt == t]


def first(v):
    return v[0] if isinstance(v, list) and v else v


def test_launch_template_imdsv2_no_public_ip_encrypted_disk():
    (lt,) = of_type("aws_launch_template")
    md = first(lt["metadata_options"])
    assert first(md["http_tokens"]) == "required"
    assert first(md["http_put_response_hop_limit"]) == 1
    ni = first(lt["network_interfaces"])
    assert first(ni["associate_public_ip_address"]) is False
    ebs = first(first(lt["block_device_mappings"])["ebs"])
    assert first(ebs["encrypted"]) is True
    assert "key_name" not in lt, "no SSH key pair; access is through SSM"


def test_web_ingress_only_from_alb_security_group():
    web_in = [b for (t, n), b in R.items() if t == "aws_vpc_security_group_ingress_rule" and n.startswith("web")]
    assert web_in, "expected ingress rules for the web SG"
    for rule in web_in:
        assert "referenced_security_group_id" in rule and "cidr_ipv4" not in rule


def test_https_listener_uses_tls13_policy():
    pols = [first(l.get("ssl_policy")) for l in of_type("aws_lb_listener") if l.get("ssl_policy")]
    assert pols and all("TLS13" in p for p in pols)


def test_alb_drops_invalid_headers():
    (lb,) = of_type("aws_lb")
    assert first(lb["drop_invalid_header_fields"]) is True


def test_cloudtrail_multi_region_validated_encrypted():
    (trail,) = of_type("aws_cloudtrail")
    assert first(trail["is_multi_region_trail"]) is True
    assert first(trail["enable_log_file_validation"]) is True
    assert "kms_key_id" in trail


def test_trail_bucket_public_access_blocked():
    (pab,) = of_type("aws_s3_bucket_public_access_block")
    for k in ("block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"):
        assert first(pab[k]) is True


def test_kms_rotation_and_guardduty_and_flow_logs():
    assert all(first(k["enable_key_rotation"]) is True for k in of_type("aws_kms_key"))
    assert of_type("aws_guardduty_detector")
    assert of_type("aws_flow_log")


def test_github_oidc_role_scoped_to_one_repo():
    text = (ROOT / "iam_github_oidc.tf").read_text()
    assert '"token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"' in text
    assert "repo:${var.github_repo}:" in text
    assert "repo:*" not in text


@pytest.mark.skipif(shutil.which("tfsec") is None, reason="tfsec not installed")
def test_tfsec_has_no_open_findings():
    p = subprocess.run(["tfsec", str(ROOT), "--format", "json", "--no-color"], capture_output=True, text=True)
    results = json.loads(p.stdout).get("results") or []
    assert results == [], [r["rule_id"] for r in results]
