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

################################################################################
# Vpc functions

get-vpcid() {
	VPCID=`aws ec2 describe-vpcs --output text --query 'Vpcs[?Tags[?Key==\`example\` && Value==\`sn1\`]].VpcId'`
	echo "$VPCID"
}

create-vpc() {
	# Check if Vpc exists
	VPCID=$(get-vpcid)	
	if [ -z "$VPCID" ] ; then
		echo "Creating VPC"
		# if vpc does not exist, create it
		#aws ec2 create-vpc --cridr-block 10.0.0.0/16
		VPCID=`aws ec2 create-vpc --cidr-block 10.0.0.0/16 --output text --query 'Vpc.VpcId'`
		aws ec2 create-tags --resources $VPCID --tags Key=example,Value=sn1		
	fi
	echo "VpcId=$VPCID"
	#aws ec2 describe-vpcs
}


delete-vpc() {
	# Now tear down the VPC.
	VPCID=$(get-vpcid)

	# VpcId found, now delete it
	if [ -n "$VPCID" ] ; then
		echo "Deleting VPC"
		aws ec2 delete-vpc --vpc-id $VPCID
	fi

	# check if deleted
	VPCID=$(get-vpcid)
	echo "VpcId=$VPCID."
	#aws ec2 describe-vpcs
}

################################################################################
# Security Group functions

SGNAME="ExampleSn1SG"  # global variable for the security group

get-sgid() {
	SGID=`aws ec2 describe-security-groups --output text --query 'SecurityGroups[?Tags[?Key==\`example\` && Value==\`sn1\`]].GroupId'`
	echo "$SGID"
}

create-sg() {
	# Get VpcId. It is a required dependency.
	VPCID=$(get-vpcid)
	
	# Check if security group exists
	SGID=$(get-sgid)
	if [ -z "$SGID" ] ; then
		echo "Creating Security Group"
		# if security-group does not exist, create it
		SGID=`aws ec2 create-security-group \
			--group-name "$SGNAME" --description "$SGNAME" \
			--vpc-id "$VPCID" \
			--output text --query 'GroupId'`
		aws ec2 create-tags --resources $SGID --tags Key=example,Value=sn1		
	fi
	echo "GroupId=$SGID"
	#aws ec2 describe-vpcs
}


delete-sg() {
	# Now tear down the security group.
	SGID=$(get-sgid)

	# If found, now delete it
	if [ -n "$SGID" ] ; then
		echo "Deleting security group"
		aws ec2 delete-security-group --group-id $SGID
	fi

	# check if deleted
	SGID=$(get-sgid)
	echo "GroupId=$SGID"
	#aws ec2 describe-security-groups
}

#
# Security Group Rules
#

get-public-ip() {
	echo "$PUBLICIP"
}

create-rules() {
	# allow ssh from our current public IP into the security group instances
		
	SGID=$(get-sgid)
	PUBLICIPv4=$(get-public-ip)

	# if security group exists, create the rules
	if [ -z "$SGID"  ] ; then
		echo "Creating Rules"
		
		SSHPORT=22
		
		aws ec2 authorize-security-group-ingress \
			--group-id=$SGID \
			--ip-permissions \
			  IpProtocol=tcp,IpRanges=[{CidrIp=${PUBLICIPv4}/32}],FromPort=$SSHPORT,ToPort=$SSHPORT
			  # note FromPort & ToPort together specify the port range to open up. 
	fi		
}

delete-rules() {		
	# Remove existing security group rules.

	SGID=$(get-sgid)
	PUBLICIPv4=$(get-public-ip)	
	
	# if security group exists, create the rules
	if [ -z "$SGID"  ] ; then
		echo "Deleting Rules"
		
		SSHPORT=22

		aws ec2 revoke-security-group-ingress \
			--group-id=$SGID \
			--ip-permissions \
			  IpProtocol=tcp,IpRanges=[{CidrIp=${PUBLICIPv4}/32}],FromPort=$SSHPORT,ToPort=$SSHPORT
	fi			
}



################################################################################
# Start point
#
case "$1" in
	gv) get-vpcid ;;
	cv) create-vpc ;;
	dv) delete-vpc ;;
	gs) get-sgid ;;		
	cs) create-sg ;;
	ds) delete-sg ;;
	cr) create-rules ;;
	dr) delete-rules ;;
	*)
		echo "Usage: $0 {gv|cv|dv|gs|cs|ds|cr|dr}"
		echo " g=get, c=create, d=delete"
		echo " v=vpc, g=security-group, r=rules" 
		exit 1
esac
