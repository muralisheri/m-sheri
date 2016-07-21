#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'This template creates an Amazon EFS file system and mount target and associates it with Amazon EC2 instances in an Auto Scaling group. **WARNING** This template creates Amazon EC2 instances and related resources. You will be billed for the AWS resources used if you create a stack from this template.'

 parameter 'InstanceType',
            :Description => 'NFS server EC2 instance type.',
            :Type => 'String',
            :Default => 'm1.medium',
            :AllowedValues => [ 'm1.medium', 'm1.large', 'm1.xlarge', 'm2.xlarge', 'm2.2xlarge', 'm2.4xlarge', 'c1.medium', 'c1.xlarge' ],
            :ConstraintDescription => 'Must be a valid EC2 instance type.'			
			
  parameter 'AsgMaxSize',
            :Type => 'Number',
            :Description => 'Maximum size and initial desired capacity of Auto Scaling Group',
            :Default => '2'

  parameter 'SSHLocation',
            :Description => 'The IP address range that can be used to connect to the EC2 instances by using SSH',
            :Type => 'String',
            :MinLength => '9',
            :MaxLength => '18',
            :Default => '0.0.0.0/0',
            :AllowedPattern => '(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})',
            :ConstraintDescription => 'must be a valid IP CIDR range of the form x.x.x.x/x.'

  parameter 'VolumeName',
            :Description => 'The name to be used for the EFS volume',
            :Type => 'String',
            :MinLength => '1',
            :Default => 'myEFSvolume'

  parameter 'MountPoint',
            :Description => 'The Linux mount point for the EFS volume',
            :Type => 'String',
            :MinLength => '1',
            :Default => 'myEFSvolume'

  mapping 'AWSInstanceType2Arch',
          :'t1.micro' => { :Arch => 'PV64' },
          :'t2.micro' => { :Arch => 'HVM64' },
          :'t2.small' => { :Arch => 'HVM64' },
          :'t2.medium' => { :Arch => 'HVM64' },
          :'m1.small' => { :Arch => 'PV64' },
          :'m1.medium' => { :Arch => 'PV64' },
          :'m1.large' => { :Arch => 'PV64' },
          :'m1.xlarge' => { :Arch => 'PV64' },
          :'m2.xlarge' => { :Arch => 'PV64' },
          :'m2.2xlarge' => { :Arch => 'PV64' },
          :'m2.4xlarge' => { :Arch => 'PV64' },
          :'m3.medium' => { :Arch => 'HVM64' },
          :'m3.large' => { :Arch => 'HVM64' },
          :'m3.xlarge' => { :Arch => 'HVM64' },
          :'m3.2xlarge' => { :Arch => 'HVM64' },
          :'c1.medium' => { :Arch => 'PV64' },
          :'c1.xlarge' => { :Arch => 'PV64' },
          :'c3.large' => { :Arch => 'HVM64' },
          :'c3.xlarge' => { :Arch => 'HVM64' },
          :'c3.2xlarge' => { :Arch => 'HVM64' },
          :'c3.4xlarge' => { :Arch => 'HVM64' },
          :'c3.8xlarge' => { :Arch => 'HVM64' },
          :'c4.large' => { :Arch => 'HVM64' },
          :'c4.xlarge' => { :Arch => 'HVM64' },
          :'c4.2xlarge' => { :Arch => 'HVM64' },
          :'c4.4xlarge' => { :Arch => 'HVM64' },
          :'c4.8xlarge' => { :Arch => 'HVM64' },
          :'g2.2xlarge' => { :Arch => 'HVMG2' },
          :'r3.large' => { :Arch => 'HVM64' },
          :'r3.xlarge' => { :Arch => 'HVM64' },
          :'r3.2xlarge' => { :Arch => 'HVM64' },
          :'r3.4xlarge' => { :Arch => 'HVM64' },
          :'r3.8xlarge' => { :Arch => 'HVM64' },
          :'i2.xlarge' => { :Arch => 'HVM64' },
          :'i2.2xlarge' => { :Arch => 'HVM64' },
          :'i2.4xlarge' => { :Arch => 'HVM64' },
          :'i2.8xlarge' => { :Arch => 'HVM64' },
          :'d2.xlarge' => { :Arch => 'HVM64' },
          :'d2.2xlarge' => { :Arch => 'HVM64' },
          :'d2.4xlarge' => { :Arch => 'HVM64' },
          :'d2.8xlarge' => { :Arch => 'HVM64' },
          :'hi1.4xlarge' => { :Arch => 'HVM64' },
          :'hs1.8xlarge' => { :Arch => 'HVM64' },
          :'cr1.8xlarge' => { :Arch => 'HVM64' },
          :'cc2.8xlarge' => { :Arch => 'HVM64' }

  mapping 'AWSRegionArch2AMI',
          :'us-east-1' => { :PV64 => 'ami-1ccae774', :HVM64 => 'ami-1ecae776', :HVMG2 => 'ami-8c6b40e4' },
          :'us-west-2' => { :PV64 => 'ami-ff527ecf', :HVM64 => 'ami-e7527ed7', :HVMG2 => 'ami-abbe919b' },
          :'us-west-1' => { :PV64 => 'ami-d514f291', :HVM64 => 'ami-d114f295', :HVMG2 => 'ami-f31ffeb7' },
          :'eu-west-1' => { :PV64 => 'ami-bf0897c8', :HVM64 => 'ami-a10897d6', :HVMG2 => 'ami-d5bc24a2' },
          :'eu-central-1' => { :PV64 => 'ami-ac221fb1', :HVM64 => 'ami-a8221fb5', :HVMG2 => 'ami-7cd2ef61' },
          :'ap-northeast-1' => { :PV64 => 'ami-27f90e27', :HVM64 => 'ami-cbf90ecb', :HVMG2 => 'ami-6318e863' },
          :'ap-southeast-1' => { :PV64 => 'ami-acd9e8fe', :HVM64 => 'ami-68d8e93a', :HVMG2 => 'ami-3807376a' },
          :'ap-southeast-2' => { :PV64 => 'ami-ff9cecc5', :HVM64 => 'ami-fd9cecc7', :HVMG2 => 'ami-89790ab3' },
		  :'ap-south-1' => { :HVM64 => 'ami-ffbdd790' },
          :'sa-east-1' => { :PV64 => 'ami-bb2890a6', :HVM64 => 'ami-b52890a8', :HVMG2 => 'NOT_SUPPORTED' },
          :'cn-north-1' => { :PV64 => 'ami-fa39abc3', :HVM64 => 'ami-f239abcb', :HVMG2 => 'NOT_SUPPORTED' }

  resource 'CloudWatchPutMetricsRole', :Type => 'AWS::IAM::Role', :Properties => {
      :AssumeRolePolicyDocument => {
          :Statement => [
              {
                  :Effect => 'Allow',
                  :Principal => { :Service => [ 'ec2.amazonaws.com' ] },
                  :Action => [ 'sts:AssumeRole' ],
              },
          ],
      },
      :Path => '/',
  }

  resource 'CloudWatchPutMetricsRolePolicy', :Type => 'AWS::IAM::Policy', :Properties => {
      :PolicyName => 'CloudWatch_PutMetricData',
      :PolicyDocument => {
          :Version => '2012-10-17',
          :Statement => [
              {
                  :Sid => 'CloudWatchPutMetricData',
                  :Effect => 'Allow',
                  :Action => [ 'cloudwatch:PutMetricData' ],
                  :Resource => [ '*' ],
              },
          ],
      },
      :Roles => [ ref('CloudWatchPutMetricsRole') ],
  }

  resource 'CloudWatchPutMetricsInstanceProfile', :Type => 'AWS::IAM::InstanceProfile', :Properties => {
      :Path => '/',
      :Roles => [ ref('CloudWatchPutMetricsRole') ],
  }

  resource 'Subnet', :Type => 'AWS::EC2::Subnet', :Properties => {
      :VpcId => 'vpc-a00bb4c5',
      :CidrBlock => '172.31.1.0/20',
      :Tags => [
          {
              :Key => 'Application',
              :Value => aws_stack_id,
          },
      ],
  }

  resource 'InstanceSecurityGroup', :Type => 'AWS::EC2::SecurityGroup', :Properties => {
      :VpcId => 'vpc-a00bb4c5',
      :GroupDescription => 'Enable SSH access via port 22',
      :SecurityGroupIngress => [
          {
              :IpProtocol => 'tcp',
              :FromPort => '22',
              :ToPort => '22',
              :CidrIp => ref('SSHLocation'),
          },
          { :IpProtocol => 'tcp', :FromPort => '80', :ToPort => '80', :CidrIp => '0.0.0.0/0' },
      ],
  }

  resource 'MountTargetSecurityGroup', :Type => 'AWS::EC2::SecurityGroup', :Properties => {
      :VpcId => 'vpc-a00bb4c5',
      :GroupDescription => 'Security group for mount target',
      :SecurityGroupIngress => [
          { :IpProtocol => 'tcp', :FromPort => '2049', :ToPort => '2049', :CidrIp => '0.0.0.0/0' },
      ],
  }

  resource 'FileSystem', :Type => 'AWS::EFS::FileSystem', :Properties => {
      :FileSystemTags => [
          {
              :Key => 'Name',
              :Value => ref('VolumeName'),
          },
      ],
  }

  resource 'MountTarget', :Type => 'AWS::EFS::MountTarget', :Properties => {
      :FileSystemId => ref('FileSystem'),
      :SubnetId => ref('Subnet'),
      :SecurityGroups => [ ref('MountTargetSecurityGroup') ],
  }

  resource 'LaunchConfiguration', :Type => 'AWS::AutoScaling::LaunchConfiguration', :Metadata => { :'AWS::CloudFormation::Init' => { :configSets => { :MountConfig => [ 'setup', 'mount' ] }, :setup => { :packages => { :yum => { :'nfs-utils' => [] } }, :files => { :'/home/ec2-user/post_nfsstat' => { :content => join('', "#!/bin/bash\n", "\n", "INPUT=\"$(cat)\"\n", "CW_JSON_OPEN='{ \"Namespace\": \"EFS\", \"MetricData\": [ '\n", "CW_JSON_CLOSE=' ] }'\n", "CW_JSON_METRIC=''\n", "METRIC_COUNTER=0\n", "\n", "for COL in 1 2 3 4 5 6; do\n", "\n", " COUNTER=0\n", " METRIC_FIELD=$COL\n", " DATA_FIELD=$(($COL+($COL-1)))\n", "\n", " while read line; do\n", "   if [[ COUNTER -gt 0 ]]; then\n", "\n", "     LINE=`echo $line | tr -s ' ' `\n", '     AWS_COMMAND="aws cloudwatch put-metric-data --region ', aws_region, "\"\n", "     MOD=$(( $COUNTER % 2))\n", "\n", "     if [ $MOD -eq 1 ]; then\n", "       METRIC_NAME=`echo $LINE | cut -d ' ' -f $METRIC_FIELD`\n", "     else\n", "       METRIC_VALUE=`echo $LINE | cut -d ' ' -f $DATA_FIELD`\n", "     fi\n", "\n", "     if [[ -n \"$METRIC_NAME\" && -n \"$METRIC_VALUE\" ]]; then\n", "       INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)\n", "       CW_JSON_METRIC=\"$CW_JSON_METRIC { \\\"MetricName\\\": \\\"$METRIC_NAME\\\", \\\"Dimensions\\\": [{\\\"Name\\\": \\\"InstanceId\\\", \\\"Value\\\": \\\"$INSTANCE_ID\\\"} ], \\\"Value\\\": $METRIC_VALUE },\"\n", "       unset METRIC_NAME\n", "       unset METRIC_VALUE\n", "\n", "       METRIC_COUNTER=$((METRIC_COUNTER+1))\n", "       if [ $METRIC_COUNTER -eq 20 ]; then\n", "         # 20 is max metric collection size, so we have to submit here\n", '         aws cloudwatch put-metric-data --region ', aws_region, " --cli-input-json \"`echo $CW_JSON_OPEN ${CW_JSON_METRIC%?} $CW_JSON_CLOSE`\"\n", "\n", "         # reset\n", "         METRIC_COUNTER=0\n", "         CW_JSON_METRIC=''\n", "       fi\n", "     fi  \n", "\n", "\n", "\n", "     COUNTER=$((COUNTER+1))\n", "   fi\n", "\n", "   if [[ \"$line\" == \"Client nfs v4:\" ]]; then\n", "     # the next line is the good stuff \n", "     COUNTER=$((COUNTER+1))\n", "   fi\n", " done <<< \"$INPUT\"\n", "done\n", "\n", "# submit whatever is left\n", 'aws cloudwatch put-metric-data --region ', aws_region, ' --cli-input-json "`echo $CW_JSON_OPEN ${CW_JSON_METRIC%?} $CW_JSON_CLOSE`"'), :mode => '000755', :owner => 'ec2-user', :group => 'ec2-user' }, :'/home/ec2-user/crontab' => { :content => join('', "* * * * * /usr/sbin/nfsstat | /home/ec2-user/post_nfsstat\n"), :owner => 'ec2-user', :group => 'ec2-user' } }, :commands => { :'01_createdir' => { :command => join('', 'mkdir /', ref('MountPoint')) } } }, :mount => { :commands => { :'01_mount' => { :command => join('', 'mount -t nfs4 $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone).', ref('FileSystem'), '.efs.', aws_region, '.amazonaws.com:/ /', ref('MountPoint')) }, :'02_permissions' => { :command => join('', 'chown ec2-user:ec2-user /', ref('MountPoint')) } } } } }, :Properties => {
      :AssociatePublicIpAddress => true,
      :ImageId => find_in_map('AWSRegionArch2AMI', aws_region, find_in_map('AWSInstanceType2Arch', ref('InstanceType'), 'Arch')),
      :InstanceType => 't2.micro',
      :KeyName => 'chef',
      :SecurityGroups => [ ref('InstanceSecurityGroup') ],
      :IamInstanceProfile => ref('CloudWatchPutMetricsInstanceProfile'),
      :UserData => base64(
          join('',
               "#!/bin/bash -xe\n",
               "yum update -y aws-cfn-bootstrap\n",
               '/opt/aws/bin/cfn-init -v ',
               '         --stack ',
               aws_stack_name,
               '         --resource LaunchConfiguration ',
               '         --configsets MountConfig ',
               '         --region ',
               aws_region,
               "\n",
               "crontab /home/ec2-user/crontab\n",
               '/opt/aws/bin/cfn-signal -e $? ',
               '         --stack ',
               aws_stack_name,
               '         --resource AutoScalingGroup ',
               '         --region ',
               aws_region,
               "\n",
          )
      ),
  }

  resource 'AutoScalingGroup', :Type => 'AWS::AutoScaling::AutoScalingGroup', :DependsOn => [ 'MountTarget' ], :CreationPolicy => { :ResourceSignal => { :Timeout => 'PT15M', :Count => ref('AsgMaxSize') } }, :Properties => {
      :VPCZoneIdentifier => [ ref('Subnet') ],
      :LaunchConfigurationName => ref('LaunchConfiguration'),
      :MinSize => '1',
      :MaxSize => ref('AsgMaxSize'),
      :DesiredCapacity => ref('AsgMaxSize'),
      :Tags => [
          { :Key => 'Name', :Value => 'EFS FileSystem Mounted Instance', :PropagateAtLaunch => 'true' },
      ],
  }

  output 'MountTargetID',
         :Description => 'Mount target ID',
         :Value => ref('MountTarget')

  output 'FileSystemID',
         :Description => 'File system ID',
         :Value => ref('FileSystem')

end.exec!
