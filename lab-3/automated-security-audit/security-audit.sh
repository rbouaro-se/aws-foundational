#!/usr/bin/env bash

# security-audit.sh
# Automated foundational AWS security posture audit
# Requirements covered:
# 1. S3 Bucket Security
#    - Public access block enabled
#    - Default encryption enabled
# 2. IAM Security
#    - Root account MFA enabled
#    - Account password policy configured
#    - Credential report generated & basic stale key detection
# 3. Additional Checks
#    - CloudTrail multi-region trail & log file validation
#    - VPC Flow Logs presence per VPC
#    - Security groups with overly permissive rules (0.0.0.0/0 on sensitive ports)
#
# Output: Pass/Fail markers (✓ / ⚠) with contextual details and final summary.
# Notes: Script reads default profile / env credentials. Use AWS_PROFILE to target others.

set -euo pipefail

ISSUE_COUNT=0
WARN() { echo -e "⚠  $1"; ((ISSUE_COUNT++)) || true; }
PASS() { echo -e "✓  $1"; }
HEADER() { echo -e "\n==================== $1 ===================="; }

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 1; }
}

require_cmd aws

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "UNKNOWN")
echo "Running security audit for Account: $ACCOUNT_ID (Profile: ${AWS_PROFILE:-default})" 

#############################################
# 1. S3 Bucket Security
#############################################
HEADER "S3 Bucket Security"
S3_BUCKETS=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null || true)
if [[ -z "$S3_BUCKETS" ]]; then
	PASS "No S3 buckets found (nothing to audit)."
else
	for b in $S3_BUCKETS; do
		# Public access block
		pab=$(aws s3api get-public-access-block --bucket "$b" --query 'PublicAccessBlockConfiguration' --output json 2>/dev/null || echo '{}')
		pab_missing=false
		if jq -e '.BlockPublicAcls and .IgnorePublicAcls and .BlockPublicPolicy and .RestrictPublicBuckets' >/dev/null 2>&1 <<<"$pab"; then
			if [[ $(jq -r '.BlockPublicAcls' <<<"$pab") == "true" && $(jq -r '.IgnorePublicAcls' <<<"$pab") == "true" && $(jq -r '.BlockPublicPolicy' <<<"$pab") == "true" && $(jq -r '.RestrictPublicBuckets' <<<"$pab") == "true" ]]; then
				pass_pab=true
			else
				pass_pab=false
			fi
		else
			pass_pab=false; pab_missing=true
		fi

		if [[ "$pass_pab" == true ]]; then
			PASS "Bucket $b: Public access block fully enabled"
		else
			WARN "Bucket $b: Public access block NOT fully enforced${pab_missing:+ (configuration missing)}"
		fi

		# Default encryption
		if aws s3api get-bucket-encryption --bucket "$b" >/dev/null 2>&1; then
			PASS "Bucket $b: Default encryption enabled"
		else
			WARN "Bucket $b: Default encryption NOT enabled"
		fi
	done
fi

#############################################
# 2. IAM Security
#############################################
HEADER "IAM Security"

# Root account MFA
ACCOUNT_SUMMARY=$(aws iam get-account-summary --output json 2>/dev/null || echo '{}')
ROOT_MFA=$(jq -r '.SummaryMap.AccountMFAEnabled // "0"' <<<"$ACCOUNT_SUMMARY")
if [[ "$ROOT_MFA" == "1" ]]; then
	PASS "Root account MFA is enabled"
else
	WARN "Root account MFA is NOT enabled"
fi

# Password policy
if aws iam get-account-password-policy >/dev/null 2>&1; then
	PASS "Password policy is configured"
else
	WARN "Password policy NOT configured"
fi

# Credential report
HEADER "IAM Credential Report"
if aws iam generate-credential-report >/dev/null 2>&1; then
	# Wait until report is ready
	for i in {1..10}; do
		status=$(aws iam get-credential-report --query 'State' --output text 2>/dev/null || true)
		[[ "$status" == "COMPLETE" ]] && break
		sleep 1
	done
	report=$(aws iam get-credential-report --output text 2>/dev/null || true)
	if [[ -n "$report" ]]; then
		PASS "Credential report generated"
		# Basic stale key detection (>90 days)
		# Credential report CSV field mapping (as of AWS docs): access_key_1_last_rotated is column 10.
		old_keys=$(echo "$report" | awk -F',' 'NR>1 {gsub(/"/,"",$1); gsub(/"/,"",$10); if($10!="N/A" && $10!="not_supported" && $10!="") {cmd="date -d "$10" +%s 2>/dev/null"; cmd | getline t; close(cmd); if(t>0){ now=systime(); age=(now-t)/86400; if(age>90) printf "%s:%d\n", $1, age } }}')
		if [[ -n "$old_keys" ]]; then
			while IFS= read -r line; do
				user=${line%%:*}; age=${line##*:}
				WARN "User $user has access key older than 90 days (~${age%.*} days)"
			done <<<"$old_keys"
		else
			PASS "No access keys older than 90 days"
		fi
	else
		WARN "Failed to retrieve credential report"
	fi
else
	WARN "Failed to generate credential report"
fi

#############################################
# 3. Additional Checks
#############################################
HEADER "Additional Checks"

# CloudTrail multi-region trail check
trails=$(aws cloudtrail describe-trails --query 'trailList[].{Name:Name,IsMultiRegionTrail:IsMultiRegionTrail,LogFileValidationEnabled:LogFileValidationEnabled}' --output json 2>/dev/null || echo '[]')
if jq -e '. | length > 0' <<<"$trails" >/dev/null; then
	multi=$(jq '[.[] | select(.IsMultiRegionTrail==true)] | length' <<<"$trails")
	if [[ $multi -gt 0 ]]; then
		PASS "CloudTrail: Multi-region trail present"
	else
		WARN "CloudTrail: No multi-region trail configured"
	fi
	validate_missing=$(jq '[.[] | select(.LogFileValidationEnabled==false)] | length' <<<"$trails")
	if [[ $validate_missing -gt 0 ]]; then
		WARN "CloudTrail: One or more trails lack log file validation"
	else
		PASS "CloudTrail: Log file validation enabled on all trails"
	fi
else
	WARN "CloudTrail: No trails configured"
fi

# VPC Flow Logs presence
VPCS=$(aws ec2 describe-vpcs --query 'Vpcs[].VpcId' --output text 2>/dev/null || true)
if [[ -z "$VPCS" ]]; then
	PASS "No VPCs found"
else
	for v in $VPCS; do
		flows=$(aws ec2 describe-flow-logs --filter Name=resource-id,Values=$v --query 'FlowLogs[].FlowLogId' --output text 2>/dev/null || true)
		if [[ -n "$flows" ]]; then
			PASS "VPC $v: Flow Logs enabled"
		else
			WARN "VPC $v: Flow Logs NOT enabled"
		fi
	done
fi

# Security groups with overly permissive ingress (0.0.0.0/0) on sensitive ports
SENSITIVE_PORTS=(22 3389 5432 3306 27017 9200)
sgs=$(aws ec2 describe-security-groups --query 'SecurityGroups[].{GroupId:GroupId,IpPermissions:IpPermissions}' --output json 2>/dev/null || echo '[]')
open_found=false
while IFS= read -r port; do
	matches=$(jq --arg p "$port" '[.[] | select(.IpPermissions[]? | (.FromPort <= ($p|tonumber) and .ToPort >= ($p|tonumber)) and (.IpRanges[]?.CidrIp == "0.0.0.0/0" or .Ipv6Ranges[]?.CidrIpv6 == "::/0"))] | length' <<<"$sgs")
	if [[ $matches -gt 0 ]]; then
		WARN "Security Groups: Port $port open to the world in $matches group(s)"
		open_found=true
	fi
done < <(printf "%s\n" "${SENSITIVE_PORTS[@]}")
[[ "$open_found" = false ]] && PASS "No sensitive ports open to world (0.0.0.0/0 or ::/0)"

#############################################
# Summary
#############################################
HEADER "Summary"
if [[ $ISSUE_COUNT -eq 0 ]]; then
	echo "All checks passed with no issues detected."
else
	echo "Total issues found: $ISSUE_COUNT"
fi

exit 0
