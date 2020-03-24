#!usr/bin/bash
RED='\033[0;31m'
NC='\033[0m'
Yellow="\033[0;33m"

### RDS SETUP #########
echo " # Please enter correct AWS Region, For Sydney ${RED}`aws configure get region`${NC}"
read REGION

echo " # Please enter db instance identifier ${Yellow}Ex: fg-<clientname> DB instance identifier is case insensitive, but stored as all lower-case ${NC}"
read DBID

echo " # Please provide master username for RDS.${Yellow} < Master Username must start with a letter. Must contain 1 to 16 alphanumeric characters > ${NC}"
read DBUSER

echo " # Please provide master password for RDS ${Yellow} < Master Password must be at least eight characters long, Master Password must be at least eight characters long, as in "mypassword". Can be any printable ASCII character except '/', '-' or '@'> ${NC}"
read DBPASS1
echo " # confirm master password for RDS"
read DBPASS2

	if [ "$DBPASS1" = "$DBPASS2" ]
	then
        	echo "${Yellow}Password looks good!${NC}"
	else
        	echo "${RED}Password doesn't match, Exit ${NC}"
        exit
	fi


echo  " # Please enter DB name ${Yellow}Ex fg<client_name>${NC} "
read DBNAME

#echo " * Avaialbe VPC details `aws ec2 describe-vpcs | grep VpcId`"

#echo " * Please enter vpc id "
#read VPCSECID

#echo " * Avaialbe VPC security groups `aws ec2 describe-security-groups | grep GroupName`"

#echo " * Please enter vpc security group "
#read VPCSECGP

echo " # Please enter security group id  "
#echo " # Avaialbe security groups are ${RED} `aws ec2 describe-security-groups | grep -A1 "GroupName"` ${NC}"
echo " # Avaialbe security groups as below, Default is:${RED}`aws ec2 describe-security-groups| grep  "GroupId" | awk '{print $1 $2}'` ${NC}"
read SECGRPID
echo "======================================================================="
echo " RDS parameter values are," 
echo "======================================================================="
echo " Region : ${RED} $REGION ${NC} "
echo " DB identifier : ${RED} $DBID ${NC} "
echo " Master user : ${RED} $DBUSER ${NC} "
echo " Master password : ${RED} $DBPASS2 ${NC} "
echo " DB name : ${RED} $DBNAME ${NC} "
echo " Security Group : ${RED} $SECGRPID ${NC} "
echo "======================================================================="
                                 

read -r -p "Proceed with RDS setup? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 

echo " Setting up RDS.. "

aws rds create-db-instance --db-instance-identifier $DBID --allocated-storage 20 --storage-type gp2 --db-instance-class db.t2.micro \
    --engine mysql --engine-version 5.7.21 --master-username $DBUSER --master-user-password $DBPASS2 \
    --vpc-security-group-ids $SECGRPID  --backup-retention-period 7 --license-model general-public-license \
    --tags "Key=$DBID,Value=$DBID"  --multi-az --publicly-accessible --region $REGION --db-name $DBNAME --port 3306 --option-group-name default:mysql-5-7       
        ;;
    *)
        echo " Exit from RDS setup "
        ;;
esac

echo " ${RED} RDS setup is completed! Please wait 2 mins for RDS endpoint creation ${NC}"
#while sleep 2 ; do printf "#"; done
sleep 2m
echo " RDS endpoint details : `aws rds describe-db-instances | grep $DBID` "
sleep 5


############# Create route53 for database ########################
echo " # Please enter subdomain name for RDS host: ${Yellow}Ex: db-<clientname> ${NC} "
read SUBDN
echo " Creating route53 for DRS.. "
#DOMAIN=fusiongrove.io
VALUE=fg-test.crs5unnpznjq.ap-southeast-2.rds.amazonaws.com.

cat > /home/ubuntu/$SUBDN-route53.json <<EOF
{
  "Comment": "Record set for $SUBDN RDS ",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "$SUBDN.mytest.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$VALUE"
          }
        ]
      }
    }
  ]
}

EOF

aws route53 change-resource-record-sets --hosted-zone-id Z1TM3VGFS1LX7R --change-batch file:///home/ubuntu/$SUBDN-route53.json
echo "RDS route53 record has been updated!"
sleep 5


################ Create route53 for vendor  ##########################

echo " # Please enter client name for vendor host: ${Yellow}Ex: <clientname> ${NC} "
read ARECORD
#ARECORD=fgclient
VALUE=mytest-184439389.ap-southeast-2.elb.amazonaws.com.

cat > /home/ubuntu/$ARECORD-route53.json <<EOF
{
  "Comment": "Record set for $ARECORD vendor",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "$ARECORD.mytest.com.",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z1GM3OXH4ZPM65",
          "DNSName": "$VALUE",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id Z1TM3VGFS1LX7R --change-batch file:///home/ubuntu/$ARECORD-route53.json
echo "Vendor route53 record has been updated!"
sleep 5


################ S3 Bucket setup ##################################################
read -r -p " # Enter the client name:${Yellow}Ex:fg-<client_name>${NC} " S3CLIENT
aws s3api create-bucket --bucket $S3CLIENT --region ap-southeast-2 --region ap-southeast-2 --create-bucket-configuration LocationConstraint=ap-southeast-2
#createbucket
echo "S3 buckect- $S3CLIENT setup has been completed!"
###################################################################################



