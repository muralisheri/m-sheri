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
			
  resource 'MyEC2Instance', :Type => 'AWS::EC2::Instance', :Properties => {
      :ImageId => 'ami-00f07917',
      :KeyName => 'chef-dk',
      :BlockDeviceMappings => [
          {
              :DeviceName => '/dev/sdm',
              :Ebs => { :VolumeType => 'gp2', :DeleteOnTermination => 'false', :VolumeSize => '20' },
          },
          {
              :DeviceName => '/dev/sdk',
              :NoDevice => {},
          },
      ],
  }

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
      :VpcId => 'vpc-b327b6d4',
      :CidrBlock => '10.0.1.0/24',
      :Tags => [
          {
              :Key => 'Application',
              :Value => aws_stack_id,
          },
      ],
  }

  resource 'InstanceSecurityGroup', :Type => 'AWS::EC2::SecurityGroup', :Properties => {
      :VpcId => 'vpc-b327b6d4',
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
      :VpcId => 'vpc-b327b6d4',
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
      :InstanceType => ref('InstanceType'),
      :KeyName => 'chef-dk',
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

  resource 'AutoScalingGroup', :Type => 'AWS::AutoScaling::AutoScalingGroup', :DependsOn => [ 'MountTarget' ], :CreationPolicy => { :ResourceSignal => { :Timeout => 'PT15M', :Count => '1' } }, :Properties => {
      :VPCZoneIdentifier => [ ref('Subnet') ],
      :LaunchConfigurationName => ref('LaunchConfiguration'),
      :MinSize => '1',
      :MaxSize => '1',
      :DesiredCapacity => '1',
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
