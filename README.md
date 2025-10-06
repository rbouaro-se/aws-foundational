# AWS Foundational

This repository contains foundational AWS and DevOps labs focusing on AWS CLI mastery, multi-region deployments, and infrastructure automation.

## Lab 1: AWS CLI Setup & Multi-Region Resource Deployment

**Duration:** 2-3 hours  
**Objective:** Master AWS CLI basics and understand global infrastructure

### Prerequisites
- AWS Account with appropriate permissions
- GitHub account
- Local terminal/command line access

### Learning Outcomes
By completing this lab, you will:
- Configure AWS CLI with multiple regional profiles
- Deploy resources across different AWS regions using automation
- Understand region-specific configuration requirements
- Implement basic cost tracking with resource tagging

## Lab Structure

### Part 1: Environment Setup
1. **AWS CLI Installation & Verification**
   - Install AWS CLI v2 for your operating system
   - Verify installation with version check
   
2. **Primary Profile Configuration**
   - Set up AWS CLI with credentials
   - Configure us-east-1 as default region
   - Set JSON output format

3. **Multi-Region Profile Setup**
   - Create `eu-region` profile for eu-west-1
   - Create `asia-region` profile for ap-southeast-1

### Part 2: Multi-Region Resource Deployment
1. **Project Repository Initialization**
   - Create `week1-aws-cli-deployment` directory
   - Initialize Git repository
   - Create project documentation

2. **S3 Bucket Deployment Script**
   - Deploy buckets across 3 regions (us-east-1, eu-west-1, ap-southeast-1)
   - Implement unique naming with timestamps
   - Handle region-specific requirements
   - Enable versioning on all buckets

3. **Resource Inventory Management**
   - Create inventory script for S3 buckets
   - Display bucket names with their regions
   - Handle regional response variations

### Part 3: Cost Analysis & Resource Management
1. **Cost Analysis Documentation**
   - Research S3 pricing across regions
   - Calculate storage costs for 100GB
   - Document data transfer costs
   - Compare regional pricing differences

2. **Resource Tagging Implementation**
   - Tag all S3 buckets with metadata
   - Include Project and Environment tags
   - Use AWS CLI tagging commands

## Expected Deliverables

### GitHub Repository Contents
- `deploy-s3-buckets.sh` - Multi-region S3 deployment script
- `list-resources.sh` - Resource inventory script
- `cost-analysis.md` - Pricing research and calculations
- `README.md` - Project documentation

### Screenshots Required
- Successful bucket creation across 3 regions
- Resource inventory script output
- AWS Console showing tagged buckets

## Evaluation Criteria
- **Functionality (40%)** - Scripts work correctly and deploy resources as specified
- **Code Quality (20%)** - Well-commented scripts following best practices
- **Documentation (20%)** - Clear README and accurate cost analysis
- **Completeness (20%)** - All deliverables submitted with proper evidence

## Key Commands Reference

### AWS CLI Profile Management
```bash
# Configure default profile
aws configure

# Configure named profiles
aws configure --profile eu-region
aws configure --profile asia-region
```

### S3 Operations
```bash
# Create bucket
aws s3api create-bucket --bucket bucket-name --region region-name

# List buckets
aws s3 ls

# Get bucket location
aws s3api get-bucket-location --bucket bucket-name

# Enable versioning
aws s3api put-bucket-versioning --bucket bucket-name --versioning-configuration Status=Enabled

# Add tags
aws s3api put-bucket-tagging --bucket bucket-name --tagging TagSet=[{Key=Project,Value=DevOps},{Key=Environment,Value=Lab}]
```

## Troubleshooting Tips
- Ensure bucket names are globally unique
- Verify IAM permissions for S3 operations
- Handle us-east-1 region special cases (returns "None" for location)
- Check script permissions with `chmod +x script-name.sh`
- Use `ls -l` to verify file permissions

## Regional Considerations
- **us-east-1**: Default region, doesn't require LocationConstraint
- **eu-west-1**: Requires LocationConstraint parameter
- **ap-southeast-1**: Requires LocationConstraint parameter

## Getting Started
1. Clone this repository
2. Navigate to the lab directory
3. Follow the lab guide step-by-step
4. Submit deliverables as specified

---

*This lab is part of the DevOps Roadmap focusing on AWS foundational skills and multi-region cloud infrastructure management.*