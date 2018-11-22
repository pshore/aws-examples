#!/bin/bash

# 
# This example replicates Scenario 1, VPC with single subnet.
# awsclient commands are used.
#
# https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenario1.html
# 
# This will be a script to create and destroy the resources in the documentation.
# It will use an idempotent approach, only creating what doesn't exist.
#
# Ansible or Terraform would be a better tool. This is just for learning.


create-vpc() {
	# Check if Vpc exists
	VPCID=`aws ec2 describe-vpcs --output text --query 'Vpcs[?Tags[?Key==\`example\` && Value==\`sn1\`]].VpcId'`
	if [ $? -gt 0 ] ; then
		echo "describe-vpcs command error" >&2
		exit 1
	fi
	if [ -z "$VPCID" ] ; then
		echo "Creating VPC"
		# if vpc does not exist, create it
		#aws ec2 create-vpc --cridr-block 10.0.0.0/16
		VPCID=`aws ec2 create-vpc --cidr-block 10.0.0.0/16 --output text --query 'Vpc.VpcId'`
		aws ec2 create-tags --resources $VPCID --tags Key=example,Value=sn1		
	fi
	echo "VpcId=$VPCID."
	#aws ec2 describe-vpcs
}


delete-vpc() {
	# Now tear down the VPC.
	VPCID=`aws ec2 describe-vpcs --output text --query 'Vpcs[?Tags[?Key==\`example\` && Value==\`sn1\`]].VpcId'`
	if [ $? -gt 0 ] ; then
		echo "describe-vpcs command error" >&2
		exit 1
	fi

	# VpcId found, now delete it
	if [ -n "$VPCID" ] ; then
		echo "Deleting VPC"
		aws ec2 delete-vpc --vpc-id $VPCID
	fi

	# check if deleted
	VPCID=`aws ec2 describe-vpcs --output text --query 'Vpcs[?Tags[?Key==\`example\` && Value==\`sn1\`]].VpcId'`
	echo "VpcId=$VPCID."
	#aws ec2 describe-vpcs
}


#
# Start point
#
case "$1" in
	cv) create-vpc ;;
	dv) delete-vpc ;;
	*)
		echo "Usage: $0 {create-vpc|delete-vpc}"
		exit 1
esac
