#!/bin/bash

# AWS S3 Multi-Region Bucket Deployment Script
# This script deploys S3 buckets across three AWS regions with versioning enabled

set -e  # Exit on any error

# Configuration
BUCKET_PREFIX="amalitech-devops"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REGIONS=("us-east-1" "eu-west-1" "ap-southeast-1")
PROFILES=("default" "eu-region" "asia-region")

echo "=== AWS S3 Multi-Region Bucket Deployment ==="
echo "Timestamp: $TIMESTAMP"
echo "Regions: ${REGIONS[@]}"
echo ""

# Function to create bucket with region-specific handling
create_bucket() {
    local region=$1
    local profile=$2
    local bucket_name="${BUCKET_PREFIX}-${region}-${TIMESTAMP}"
    
    echo "Creating bucket in $region using profile $profile..."
    
    # Handle us-east-1 special case (no LocationConstraint needed)
    if [ "$region" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$bucket_name" \
            --region "$region" \
            --profile "$profile"
    else
        # Other regions require LocationConstraint
        aws s3api create-bucket \
            --bucket "$bucket_name" \
            --region "$region" \
            --create-bucket-configuration LocationConstraint="$region" \
            --profile "$profile"
    fi
    
    if [ $? -eq 0 ]; then
        echo "✓ Bucket $bucket_name created successfully in $region"
        
        # Enable versioning on the bucket
        echo "  Enabling versioning on $bucket_name..."
        aws s3api put-bucket-versioning \
            --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled \
            --profile "$profile"
        
        if [ $? -eq 0 ]; then
            echo "  ✓ Versioning enabled on $bucket_name"
        else
            echo "  ✗ Failed to enable versioning on $bucket_name"
        fi
        
        # Add tags to the bucket
        echo "  Adding tags to $bucket_name..."
        aws s3api put-bucket-tagging \
            --bucket "$bucket_name" \
            --tagging 'TagSet=[{Key=Project,Value=DevOps},{Key=Environment,Value=Lab},{Key=Region,Value='$region'},{Key=CreatedDate,Value='$TIMESTAMP'}]' \
            --profile "$profile"
        
        if [ $? -eq 0 ]; then
            echo "  ✓ Tags added to $bucket_name"
        else
            echo "  ✗ Failed to add tags to $bucket_name"
        fi
        
    else
        echo "✗ Failed to create bucket $bucket_name in $region"
        return 1
    fi
    
    echo ""
}

# Function to verify AWS CLI profiles
verify_profiles() {
    echo "Verifying AWS CLI profiles..."
    for i in "${!PROFILES[@]}"; do
        profile=${PROFILES[$i]}
        region=${REGIONS[$i]}
        
        echo "  Checking profile: $profile (${region})..."
        
        if [ "$profile" = "default" ]; then
            aws sts get-caller-identity --region "$region" > /dev/null 2>&1
        else
            aws sts get-caller-identity --profile "$profile" --region "$region" > /dev/null 2>&1
        fi
        
        if [ $? -eq 0 ]; then
            echo "  ✓ Profile $profile is configured correctly"
        else
            echo "  ✗ Profile $profile is not configured or has issues"
            echo "  Please run: aws configure --profile $profile"
            exit 1
        fi
    done
    echo ""
}

# Function to list created buckets
list_created_buckets() {
    echo "=== Deployment Summary ==="
    echo "Listing all S3 buckets with timestamp $TIMESTAMP:"
    
    aws s3 ls | grep "$TIMESTAMP" || echo "No buckets found with timestamp $TIMESTAMP"
    echo ""
}

# Main execution
main() {
    echo "Starting S3 bucket deployment across multiple regions..."
    echo ""
    
    # Verify profiles before starting
    verify_profiles
    
    # Create buckets in each region
    for i in "${!REGIONS[@]}"; do
        region=${REGIONS[$i]}
        profile=${PROFILES[$i]}
        
        create_bucket "$region" "$profile"
        
        # Add a small delay between deployments
        sleep 2
    done
    
    echo "=== Deployment Complete ==="
    echo "All buckets have been created with the following features:"
    echo "  ✓ Unique names with timestamp: $TIMESTAMP"
    echo "  ✓ Versioning enabled"
    echo "  ✓ Proper regional configuration"
    echo "  ✓ Resource tags applied"
    echo ""
    
    # Show deployment summary
    list_created_buckets

}

# Execute main function
main