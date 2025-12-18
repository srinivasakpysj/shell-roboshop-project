#!/bin/bash
# Shebang: Ensures the script runs using the Bash shell

AMI_ID="ami-09c813fb71547fc4f"
# AMI ID used to launch all EC2 instances (Amazon Machine Image)

SG_ID="sg-02aa3db70763a0701"
# Security Group ID to attach to the EC2 instances

INSTANCES=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")
# Array containing all Roboshop service instance names

ZONE_ID="Z05564583KGI8O0CV6ITO"
# Route53 Hosted Zone ID where DNS records will be created/updated

DOMAIN_NAME="srinivasak.online"
# Base domain name for Route53 DNS records

# Loop through instance names passed as command-line arguments
# Example usage: ./script.sh mongodb redis frontend
for instance in "$@"
do
    # Create an EC2 instance with the given AMI, instance type, and security group
    # Also tag the instance with Name=<service-name>
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type t3.micro \
        --security-group-ids "$SG_ID" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
        --query "Instances[0].InstanceId" \
        --output text)

    # Check if the instance is NOT frontend
    if [ "$instance" != "frontend" ]
    then
        # Fetch the Private IP for backend services
        IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query "Reservations[0].Instances[0].PrivateIpAddress" \
            --output text)

        # DNS record will be <service>.domain.com (e.g., mongodb.srinivasak.online)
        RECORD_NAME="$instance.$DOMAIN_NAME"
    else
        # Fetch the Public IP only for frontend instance
        IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query "Reservations[0].Instances[0].PublicIpAddress" \
            --output text)

        # Frontend uses root domain (srinivasak.online)
        RECORD_NAME="$DOMAIN_NAME"
    fi

    # Print instance name and its resolved IP address
    echo "$instance IP address: $IP"

    # Create or update Route53 DNS A record using UPSERT
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$ZONE_ID" \
        --change-batch '
        {
            "Comment": "Creating or updating DNS record for Roboshop service",
            "Changes": [{
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "'"$RECORD_NAME"'",
                    "Type": "A",
                    "TTL": 1,
                    "ResourceRecords": [{
                        "Value": "'"$IP"'"
                    }]
                }
            }]
        }'
done
