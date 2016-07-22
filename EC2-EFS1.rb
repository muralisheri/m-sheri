#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'Ec2 block device mapping'
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
          :'t2.micro' => { :Arch => 'HVM64' }
          
  mapping 'AWSRegionArch2AMI',
          :'us-east-1' => { :HVM64 => 'ami-00f07917' }
           
  resource 'MyEC2Instance', :Type => 'AWS::EC2::Instance', :Properties => {
      :InstanceType => 't2.micro',
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
          }
      ]
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
      :SubnetId => 'subnet-d304d8a4',
	  :SecurityGroups => [ 'sg-2cf4df49' ],
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
  
  resource 'LaunchConfiguration', :Type => 'AWS::AutoScaling::LaunchConfiguration', :Metadata => { :'AWS::CloudFormation::Init' => { :configSets => { :MountConfig => [ 'setup', 'mount' ] }, :setup => { :packages => { :yum => { :'nfs-utils' => [] } }, :files => { :'/home/ec2-user/post_nfsstat' => { :content => join('', "#!/bin/bash\n", "\n", "INPUT=\"$(cat)\"\n", "CW_JSON_OPEN='{ \"Namespace\": \"EFS\", \"MetricData\": [ '\n", "CW_JSON_CLOSE=' ] }'\n", "CW_JSON_METRIC=''\n", "METRIC_COUNTER=0\n", "\n", "for COL in 1 2 3 4 5 6; do\n", "\n", " COUNTER=0\n", " METRIC_FIELD=$COL\n", " DATA_FIELD=$(($COL+($COL-1)))\n", "\n", " while read line; do\n", "   if [[ COUNTER -gt 0 ]]; then\n", "\n", "     LINE=`echo $line | tr -s ' ' `\n", '     AWS_COMMAND="aws cloudwatch put-metric-data --region ', aws_region, "\"\n", "     MOD=$(( $COUNTER % 2))\n", "\n", "     if [ $MOD -eq 1 ]; then\n", "       METRIC_NAME=`echo $LINE | cut -d ' ' -f $METRIC_FIELD`\n", "     else\n", "       METRIC_VALUE=`echo $LINE | cut -d ' ' -f $DATA_FIELD`\n", "     fi\n", "\n", "     if [[ -n \"$METRIC_NAME\" && -n \"$METRIC_VALUE\" ]]; then\n", "       INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)\n", "       CW_JSON_METRIC=\"$CW_JSON_METRIC { \\\"MetricName\\\": \\\"$METRIC_NAME\\\", \\\"Dimensions\\\": [{\\\"Name\\\": \\\"InstanceId\\\", \\\"Value\\\": \\\"$INSTANCE_ID\\\"} ], \\\"Value\\\": $METRIC_VALUE },\"\n", "       unset METRIC_NAME\n", "       unset METRIC_VALUE\n", "\n", "       METRIC_COUNTER=$((METRIC_COUNTER+1))\n", "       if [ $METRIC_COUNTER -eq 20 ]; then\n", "         # 20 is max metric collection size, so we have to submit here\n", '         aws cloudwatch put-metric-data --region ', aws_region, " --cli-input-json \"`echo $CW_JSON_OPEN ${CW_JSON_METRIC%?} $CW_JSON_CLOSE`\"\n", "\n", "         # reset\n", "         METRIC_COUNTER=0\n", "         CW_JSON_METRIC=''\n", "       fi\n", "     fi  \n", "\n", "\n", "\n", "     COUNTER=$((COUNTER+1))\n", "   fi\n", "\n", "   if [[ \"$line\" == \"Client nfs v4:\" ]]; then\n", "     # the next line is the good stuff \n", "     COUNTER=$((COUNTER+1))\n", "   fi\n", " done <<< \"$INPUT\"\n", "done\n", "\n", "# submit whatever is left\n", 'aws cloudwatch put-metric-data --region ', aws_region, ' --cli-input-json "`echo $CW_JSON_OPEN ${CW_JSON_METRIC%?} $CW_JSON_CLOSE`"'), :mode => '000755', :owner => 'ec2-user', :group => 'ec2-user' }, :'/home/ec2-user/crontab' => { :content => join('', "* * * * * /usr/sbin/nfsstat | /home/ec2-user/post_nfsstat\n"), :owner => 'ec2-user', :group => 'ec2-user' } }, :commands => { :'01_createdir' => { :command => join('', 'mkdir /', ref('MountPoint')) } } }, :mount => { :commands => { :'01_mount' => { :command => join('', 'mount -t nfs4 $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone).', ref('FileSystem'), '.efs.', aws_region, '.amazonaws.com:/ /', ref('MountPoint')) }, :'02_permissions' => { :command => join('', 'chown ec2-user:ec2-user /', ref('MountPoint')) } } } } }, :Properties => {
      :AssociatePublicIpAddress => true,
	  :ImageId => find_in_map('AWSRegionArch2AMI', aws_region, find_in_map('AWSInstanceType2Arch', ref('MyEC2Instance'), 'Arch')),
      :InstanceType => ref('MyEC2Instance'),
      :KeyName => 'chef-dk',
      :SecurityGroups => [ 'sg-2cf4df49' ],
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
end.exec!