# Security Remediation Plan

Based on the findings from `security-audit.sh` (latest run saved in `audit-results.txt`), the following issues were identified and prioritized.

## Summary of Findings

| Severity      | Count | Issues                                          |
| ------------- | ----- | ----------------------------------------------- |
| Critical      | 1     | CloudTrail not configured                       |
| High          | 2     | SSH (22) open to world; Password policy missing |
| Medium        | 1     | VPC Flow Logs disabled                          |
| Low           | 1     | S3 bucket missing complete public access block  |
| Informational | 1     | (No stale access keys > 90 days)                |

## Critical Issues

### Issue 1: No CloudTrail Trail Configured (Multi-Region Absent)

-  **Description:** CloudTrail is not enabled; no trails were returned by `aws cloudtrail describe-trails`.
-  **Impact:** Absence of CloudTrail hinders forensic investigations, incident response, compliance evidence, and anomaly detection. Malicious or accidental API activity could go undetected.
-  **Remediation Steps:**
   1. Create an S3 bucket for logs (private, versioning & default encryption enabled). Example: `aws s3 mb s3://<account>-cloudtrail-logs-<region>`
   2. Apply a bucket policy allowing CloudTrail service principal to write logs.
   3. Enable an organization or multi-region trail: `aws cloudtrail create-trail --name org-trail --s3-bucket-name <bucket> --is-multi-region-trail --enable-log-file-validation --include-global-service-events`
   4. Start logging: `aws cloudtrail start-logging --name org-trail`
   5. (Optional) Add CloudWatch Logs integration for real-time metric filters / alarms.
   6. Validate delivery: Check S3 prefix for log files; ensure log file validation passes.
-  **Time Estimate:** 1 hour
-  **Owner:** DevOps Team
-  **Deadline:** 2025-10-13 (Immediate)

## High Issues

### Issue 2: Security Groups Allow SSH (Port 22) From 0.0.0.0/0

-  **Description:** The audit reported Port 22 open to the world in 3 security groups.
-  **Impact:** Increases brute force & unauthorized access risk; facilitates lateral movement if credentials compromised.
-  **Remediation Steps:**
   1. Identify groups: `aws ec2 describe-security-groups --filters Name=ip-permission.from-port,Values=22 Name=ip-permission.cidr,Values=0.0.0.0/0`
   2. Replace with least-privilege CIDR (corporate VPN / bastion host) or remove rule entirely if using SSM Session Manager.
   3. Apply changes: `aws ec2 revoke-security-group-ingress --group-id <sg-id> --protocol tcp --port 22 --cidr 0.0.0.0/0`
   4. (Optional) Enable SSM Session Manager for keyless managed access to instances.
   5. Document new standard: No direct SSH from the Internet.
-  **Time Estimate:** 1 hour
-  **Owner:** DevOps Team
-  **Deadline:** 2025-10-20

### Issue 3: IAM Account Password Policy Not Configured

-  **Description:** `aws iam get-account-password-policy` failed—no policy defined.
-  **Impact:** User accounts (if any) may have weak passwords, increasing risk of compromise via credential stuffing / brute force.
-  **Remediation Steps:**
   1. Define policy (min length 14, require uppercase, lowercase, number, symbol, 90-day rotation, prevent reuse). Example JSON not directly settable—must use parameters.
   2. Apply: `aws iam update-account-password-policy --minimum-password-length 14 --require-symbols --require-numbers --require-uppercase-characters --require-lowercase-characters --allow-users-to-change-password --max-password-age 90 --password-reuse-prevention 5`
   3. Notify IAM users of new policy & rotation expectations.
   4. Add periodic audit: Run quarterly review of password policy & usage.
-  **Time Estimate:** 0.5 hour
-  **Owner:** DevOps Team
-  **Deadline:** 2025-10-20

## Medium Issues

### Issue 4: VPC Flow Logs Not Enabled (vpc-08f432aa46478bf89)

-  **Description:** No Flow Logs found for at least one VPC.
-  **Impact:** Lack of network traffic visibility hinders detection of anomalous connections, exfiltration, or misconfigurations.
-  **Remediation Steps:**
   1. Create a CloudWatch Logs log group (e.g., `/vpc/flow-logs`) with retention (e.g., 90 days): `aws logs create-log-group --log-group-name /vpc/flow-logs` (ignore if exists).
   2. Create an IAM role / resource policy permitting VPC Flow Logs delivery.
   3. Enable Flow Logs: `aws ec2 create-flow-logs --resource-type VPC --resource-ids vpc-08f432aa46478bf89 --traffic-type ALL --log-group-name /vpc/flow-logs --deliver-logs-permission-arn arn:aws:iam::<account-id>:role/<FlowLogsRole>`
   4. Validate logs appearing; set retention & alerts for unusual rejected traffic.
-  **Time Estimate:** 1 hour
-  **Owner:** DevOps Team
-  **Deadline:** 2025-10-27

## Low Issues

### Issue 5: S3 Bucket Missing Complete Public Access Block (java-upskilling)

-  **Description:** Bucket `java-upskilling` lacks one or more of the four PublicAccessBlock settings (BlockPublicAcls, IgnorePublicAcls, BlockPublicPolicy, RestrictPublicBuckets).
-  **Impact:** Increased risk of inadvertent public exposure via ACL or bucket policy misconfiguration.
-  **Remediation Steps:**
   1. Review intended access model—if strictly private, enforce full public access block.
   2. Apply configuration: `aws s3api put-public-access-block --bucket java-upskilling --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true`
   3. Confirm: `aws s3api get-public-access-block --bucket java-upskilling`.
   4. Add guardrail: (Optional) Use AWS Config rule `s3-bucket-public-read-prohibited` & `s3-bucket-public-write-prohibited`.
-  **Time Estimate:** 0.25 hour
-  **Owner:** DevOps Team
-  **Deadline:** 2025-11-10

## Informational (No Action Required)

### Observation: No Access Keys Older Than 90 Days

-  **Description:** Credential report indicates all active access keys are <=90 days old or non-existent.
-  **Benefit:** Reduces risk of compromised long-lived credentials.
-  **Recommended Ongoing Practice:** Implement automated monthly key age check & enforce rotation > 90 days with notification.

## Tracking & Governance

| Control Area        | Immediate Action                     | Long-Term Enhancement                                |
| ------------------- | ------------------------------------ | ---------------------------------------------------- |
| Logging & Audit     | Enable CloudTrail multi-region trail | Add CloudTrail Lake & event-based anomaly detection  |
| Network Visibility  | Enable Flow Logs                     | Centralize analysis (Athena / OpenSearch)            |
| IAM Hygiene         | Set password policy                  | Automate periodic credential report parsing & alerts |
| Perimeter Hardening | Lock down SSH                        | Adopt SSM Session Manager / zero-SSH baseline        |
| Data Protection     | Enforce S3 public access blocks      | Add Config + SCP guardrails across accounts          |

## Acceptance Criteria

-  All Critical & High issues remediated by their deadlines.
-  CloudTrail delivering validated logs; sample event confirmed.
-  SSH exposure eliminated (0 security groups with 0.0.0.0/0 on port 22).
-  Password policy returns success with required complexity.
-  Flow Logs producing entries for accepted & rejected traffic.
-  S3 public access block returns all four flags true for java-upskilling.

## Verification Steps (Post-Remediation)

| Issue                  | Verification Command                                                                                                                                   |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CloudTrail enabled     | `aws cloudtrail describe-trails` (check IsMultiRegionTrail=true)                                                                                       |
| SSH restricted         | `aws ec2 describe-security-groups --query 'SecurityGroups[].IpPermissions[?ToPort==\`22\` && IpRanges[?CidrIp==\`0.0.0.0/0\`]]'` (should return empty) |
| Password policy        | `aws iam get-account-password-policy` (validate parameters)                                                                                            |
| Flow Logs              | `aws ec2 describe-flow-logs --filter Name=resource-id,Values=vpc-08f432aa46478bf89` (FlowLogId present)                                                |
| S3 public access block | `aws s3api get-public-access-block --bucket java-upskilling` (all true)                                                                                |

