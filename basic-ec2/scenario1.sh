#!/bin/bash

# 
# This example replicates Scenario 1 using the AWS command line client.
# A VPC with single subnet and one EC2 instance is created.
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

#
# Key Pair functions
#

KEYPAIRNAME="ExampleKP"  # global variable for the key-pair name

get-key-pair-fingerprint() {
	KPFP=`aws ec2 describe-key-pairs --output text --query 'KeyPairs[?KeyName==\`ExampleKP\`].KeyFingerprint'`
	echo "$KPFP"
}

create-key-pair() {
	# create a keypair 
	if [ ! -f ~/.ssh/${KEYPAIRNAME}_id_rsa ] ; then
		# genereate an RSA keypair with no passphrase.
		ssh-keygen -q -t rsa -N "" -f ~/.ssh/${KEYPAIRNAME}_id_rsa	
	fi

	KPFP=$(get-key-pair-fingerprint)
	if [ -z "$KPFP"  ] ; then
		echo "Importing local public key to EC2."
		aws ec2 import-key-pair --key-name ${KEYPAIRNAME} \
			--public-key-material file://~/.ssh/${KEYPAIRNAME}_id_rsa.pub
	fi
}

delete-key-pair() {
	aws ec2 delete-key-pair --key-name ${KEYPAIRNAME}	
	
	# could delete the local private key here.
	echo "To permanently delete the private key, run: \n\t rm -f ~/.ssh/${KEYPAIRNAME}_id_rsa.*"
}

################################################################################
# EC2 Instance functions

get-instanceid() {
	#pending->running->terminated
	
	# get the id of any pending or running instance. Assumes only one will ever be returned.
	INID=`aws ec2 describe-instances --output text \
	  --query 'Reservations[].Instances[?Tags[?Key==\`example\` && Value==\`sn1\`] && State.Name==\`running\` || State.Name==\`pending\`].InstanceId'`
	echo "$INID"
}

get-instance-ip() {
	INID=$(get-instanceid)
	INIP=`aws ec2 describe-instances --instance-ids ${INID} --query 'Reservations[*].Instances[*].PublicIpAddress' --output text`
	echo "$INIP"
}

get-instance-ssh() {
	INIP=$(get-instance-ip)
	echo "ssh -i ~/.ssh/${KEYPAIRNAME}_id_rsa ec2-user@${INIP}"
}

AMIID="ami-09693313102a30b2c" # Amazon Linux 2 AMI (HVM), SSD Volume Type
AMITYPE="t2.micro" # global variable for free tier eligible type

# Create and run an instance
create-instance() {

	SGID=$(get-sgid)
	
	INID=$(get-instanceid)
	
	if [ -z "$INID"  ] ; then
		echo "Creating instance in ${SGID}."
		
		aws ec2 run-instances --image-id ${AMIID} --count 1 --instance-type ${AMITYPE} \
			--key-name ${KEYPAIRNAME} \
			--security-group-ids ${SGID} #\ 
			#--tag-specifications "ResourceType=instance,Tags=[{Key=example,Value=sn1}]"			
				
		INID=$(get-instanceid)			
		aws ec2 create-tags --resources $INID --tags Key=example,Value=sn1
	fi

	# SSH as follows:
	# ssh -i ~/.ssh/ExampleKP_id_rsa ec2user@<public-ip>
}

delete-instance() {
	INID=$(get-instanceid)

	# VpcId found, now delete it
	if [ -n "$INID" ] ; then
		echo "Deleting instance ${INID}"
		aws ec2 terminate-instances --instance-ids $INID
	fi
}

# Refer to instance lifecycle
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html

# How to patch
# https://aws.amazon.com/blogs/security/how-to-patch-linux-workloads-on-aws/


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
	gk) get-key-pair-fingerprint ;;
	ck) create-key-pair ;;
	dk) delete-key-pair ;;
	gi) get-instanceid ;;
	ci) create-instance ;;	
	di) delete-instance ;;
	ssh) get-instance-ssh ;;
	*)
		echo "Usage: $0 {gv|cv|dv|gs|cs|ds|cr|dr|gk|ck|dk|gi|ci|di|ssh}"
		echo " g=get, c=create, d=delete"
		echo " v=vpc, g=security-group, r=rules, k=key-pair, i=instance" 
		echo " ssh=show the ssh command required to connect"
		exit 1
esac
