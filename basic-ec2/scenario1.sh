#!/bin/bash

# 
# This example replicates Scenario 1, VPC with single subnet.
# awsclient commands are used.
#
# https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenario1.html
# 

# This will be a script to create and destroy the resources in the documentation.
# It will use an idempotent approach, only creating what doesn't exist.
# For now, it's just a collection of useful commands.
# 

#
# The create sequence
#

# Check if Vpc exists
VPCID=`aws ec2 describe-vpcs --output text --query 'Vpcs[?Tags[?Key==\`example\` && Value==\`sn1\`]].VpcId'
# todo - check the result

# if vpc does not exist, create it
aws ec2 create-vpc --cridr-block 10.0.0.0/16
aws ec2 create-tags --resources $VPCID --tags Key=example,Value=sn1
VPCID=`aws ec2 create-vpc --cidr-block 10.0.0.0/16 --output text --query 'Vpc.VpcId'`


echo $VPCID
#aws ec2 describe-vpcs


#
# The destroy sequence
#

# Now tear down the VPC.
aws ec2 delete-vpc --vpc-id $VPCID


