# AWS Well-Architected Review

This document evaluates the 3-tier web application architecture (with VPC, ALB, EC2 web/app tiers, and RDS) against the six pillars of the AWS Well-Architected Framework.

---

## 1. Operational Excellence

### 1.1 Current State

-  Architecture spans two Availability Zones (AZs).
-  Web tier EC2 instances reside in public subnets (ingress controlled by ALB + security groups).
-  App tier EC2 instances reside in private subnets; accept traffic only from the Web tier and reach the internet via the NAT Gateway for updates/dependencies.
-  Application Load Balancer handles incoming requests.
-  Manual deployment process.

### 1.2 Risks

-  No automated monitoring or alerting.
-  Manual deployments may lead to downtime or errors.
-  Lack of centralized logging (e.g., CloudWatch Logs, CloudTrail).

### 1.3 Improvements

1. Implement **AWS CloudWatch Alarms and Dashboards** for proactive monitoring.
2. Use **AWS CloudFormation** or **Terraform** for infrastructure as code.
3. Introduce **AWS Systems Manager** for centralized operations and patch management.

---

## 2. Security

### 2.1 Current State

-  Public and private subnets separate public-facing and internal resources.
-  Security groups restrict inbound/outbound traffic.
-  RDS is in private subnets.

### 2.2 Risks

-  No encryption specified for data at rest or in transit.
-  Lack of centralized IAM policy enforcement.
-  No logging/auditing configured.

### 2.3 Improvements

1. Enable **encryption at rest** (RDS, EBS) and **in transit** (HTTPS, TLS).
2. Configure **AWS CloudTrail** and **VPC Flow Logs** for auditing.
3. Apply **least privilege IAM roles and policies** for EC2, RDS, and users.

---

## 3. Reliability

### 3.1 Current State

-  Multi-AZ deployment for high availability.
-  ALB distributes traffic across AZs.
-  RDS deployed as a Multi-AZ instance (primary with synchronous standby) for database high availability.

### 3.2 Risks

-  No defined backup or recovery plan.
-  No Auto Scaling for EC2 tiers.
-  RDS failover procedure not yet tested/documented (operational readiness risk).

### 3.3 Improvements

1. Validate and document **RDS Multi-AZ failover** (perform a controlled failover drill; capture RTO/RPO, update runbook).
2. Configure **Auto Scaling Groups (ASG)** for EC2 instances.
3. Implement and verify **automated backups & snapshots** (test point-in-time recovery; define retention & lifecycle policies) for RDS and EC2.

---

## 4. Performance Efficiency

### 4.1 Current State

-  EC2 instances handle web and app workloads.
-  ALB manages traffic distribution.
-  VPC is distributed across two AZs.

### 4.2 Risks

-  Instance types may not be optimized for workload.
-  No caching layer (e.g., CloudFront, ElastiCache).
-  Manual scaling limits performance under high load.

### 4.3 Improvements

1. Implement **Auto Scaling** to adjust capacity dynamically.
2. Use **Amazon CloudFront** as a CDN for static content.
3. Consider **ElastiCache** to reduce load on the database.

---

## 5. Cost Optimization

### 5.1 Current State

-  Basic 3-tier setup using on-demand EC2 instances and RDS.
-  Two NAT Gateways (one per AZ).

### 5.2 Risks

-  NAT Gateways and EC2 instances may remain underutilized.
-  On-demand pricing can lead to higher costs.
-  No cost monitoring or budgeting tools in place.

### 5.3 Improvements

1. Use **Savings Plans or Reserved Instances** for predictable workloads.
2. Consolidate or scale down underutilized resources.
3. Enable **AWS Cost Explorer** and **Budgets** to track usage and costs.

---

## 6. Sustainability

### 6.1 Current State

-  Two AZs provide high availability.
-  EC2 instances run continuously.

### 6.2 Risks

-  Always-on resources increase energy consumption.
-  Over-provisioning leads to waste.
-  No use of managed or serverless options.

### 6.3 Improvements

1. Use **Auto Scaling** and **on-demand start/stop schedules** to reduce idle time.
2. Consider **AWS Lambda** for certain workloads to improve efficiency.
3. Right-size EC2 instances to match actual demand.

## Most Immediate Scalability Constraints

The following EC2 service quotas (per region) represent the near‑term ceilings that can restrict horizontal scaling, resilience headroom, or cost optimization strategies for the current 3‑tier architecture.

### Key Quotas Overview

| Quota (Console Label)                                            | Code       | Current | Risk\*                           | Why It Limits Scalability / Architecture Impact                                                               | Recommended Action (Target)                                                    |
| ---------------------------------------------------------------- | ---------- | ------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances | L-1216C47A | 16      | Medium (growth, rolling deploys) | Hard cap on aggregate Web + App + Bastion on-demand capacity; reduces surge & deployment buffer               | Request increase to 50 (initial) / 100 (strategic); add utilization alarms     |
| All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests  | L-34B43A08 | 32      | Low now / High future            | Limits breadth of Spot diversification & burst scaling when adopting Spot for stateless tiers                 | Plan increase to 100 before large Spot rollout; diversify families             |
| EC2-VPC Elastic IPs                                              | L-0263D0A3 | 5       | Medium                           | 2 NAT GWs + Bastion + future public endpoints can exhaust pool; constrains multi‑AZ & public ingress patterns | Optimize (PrivateLink, Interface Endpoints, consolidate NAT) or raise to 10–15 |
| Public AMIs                                                      | L-0E3CBAB9 | 5       | Low                              | Caps number of golden images if publishing hardened AMIs externally                                           | Monitor; request only if pipeline requires >5                                  |

\*Risk reflects likelihood of exceeding the current value within the next scaling phase (3–12 months) given typical growth for a small/medium 3‑tier workload.

### Detailed Notes

1. On-Demand Standard Instances (L-1216C47A): With separate ASGs (e.g., Web max=8, App max=8) plus 1–2 auxiliary instances, headroom disappears; rolling deployments and failover need surplus capacity → increase early.
2. Spot Requests (L-34B43A08): Adequate now; becomes a throttle once cost optimization shifts >~40–50% of stateless capacity to Spot.
3. Elastic IPs (L-0263D0A3): Current pattern (dual NAT) already consumes 40% of quota; additional EIPs (e.g., bastion, specialized public endpoints) quickly create friction.
4. Public AMIs (L-0E3CBAB9): Non-blocking; include in image pipeline governance checklist.

### Action Checklist

-  [ ] Forecast ASG desired / max for Web & App (3, 6, 12‑month horizons); document vs current quota.
-  [ ] Submit quota increase request for L-1216C47A before >60% steady-state utilization (target 50 now, 100 later).
-  [ ] Implement CloudWatch (or EventBridge + Lambda) check comparing running instance counts vs quota (alarm at 75%).
-  [ ] Evaluate NAT/EIP strategy: Can one NAT + Interface Endpoints meet requirements? If not, request EIP increase (L-0263D0A3 to 10+).
-  [ ] Define Spot adoption roadmap; trigger preemptive raise of L-34B43A08 before mixed-instance policies push near 32 active requests.
-  [ ] Add Service Quotas usage report to weekly ops review.

### Example CLI Requests

```bash
# Increase On-Demand Standard instances quota
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --desired-value 50

# Increase Elastic IP quota
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-0263D0A3 \
  --desired-value 10

# (Prepare for expanded Spot usage)
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-34B43A08 \
  --desired-value 100
```

### Success Indicators

-  Quota utilization for critical limits (On-Demand, EIPs) consistently <70% outside controlled load tests.
-  Approved increase for L-1216C47A before ASG scaling events require >16 instances.
-  Alerting in place for >75% utilization of any growth-sensitive quota.
-  Documented decision (ADR) on NAT/EIP architecture trade-offs.
