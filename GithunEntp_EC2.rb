#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'GithubEntp.'

  parameter 'VolumeName',
            :Description => 'The name to be used for the EFS volume',
            :Type => 'String',
            :MinLength => '1',
            :Default => 'myvolume'

  resource 'MyEC2Instance', :Type => 'AWS::EC2::Instance', :Properties => {
      :InstanceType => 'm3.xlarge',
      :ImageId => 'ami-028f1015',
      :KeyName => 'chef-dk',
	  :VpcId => 'vpc-b327b6d4',
      :CidrBlock => '10.0.0.0/24',
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
      :GroupDescription => 'Enable SSH access via port 122',
      :SecurityGroupIngress => [
          {
              :IpProtocol => 'tcp',
              :FromPort => '122',
              :ToPort => '122',
              :CidrIp => ref('Subnet'),
          },
          { :IpProtocol => 'tcp', :FromPort => '80', :ToPort => '80', :CidrIp => '0.0.0.0/0' },
		],
  }
end.exec!
