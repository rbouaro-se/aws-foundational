#!/bin/bash

# Get s3 buckets list with 'amalitech' in the name (the 3 buckets created in the previous lab)
BUCKETS=($(aws s3api list-buckets --query "Buckets[?contains(Name, 'amalitech')].Name" --output text)) 

echo "Buckets to be tagged: ${BUCKETS[@]}"

# Tagging each bucket
for BUCKET in "${BUCKETS[@]}"; do
    aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging "TagSet=[{Key=Owner,Value=rBOUARO}]"
done

echo "Tagging completed for all buckets."
