#!/bin/bash

# AWS S3 Resource Inventory Script
# This script lists all S3 buckets with their regions and handles us-east-1 special case

set -e  # Exit on any error

list_all_buckets() {
    echo "=== S3 Buckets Inventory ==="
    
    # Get list of all bucket names
    local buckets_list=$(aws s3 ls --output text | awk '{print $3}')
    
    if [ -z "$buckets_list" ]; then
        echo "No S3 buckets found in your account."
        return
    fi
    
    # Process each bucket
    while IFS= read -r bucket_name; do
        if [ -n "$bucket_name" ]; then
            # Get bucket region
            local region_output=$(aws s3api get-bucket-location --bucket "$bucket_name" --output text 2>/dev/null)
            
            # Handle us-east-1 special case where it returns "None"
            if [ "$region_output" = "None" ] || [ -z "$region_output" ]; then
                local region="us-east-1"
            else
                local region="$region_output"
            fi
            
            # Display in required format
            echo "Bucket: $bucket_name | Region: $region"
        fi
    done <<< "$buckets_list"
}

# Main execution
main() {
    echo "AWS S3 Resource Inventory Tool"
    echo "Generated on: $(date)"
    echo ""
    
    list_all_buckets

}

# Execute main function
main