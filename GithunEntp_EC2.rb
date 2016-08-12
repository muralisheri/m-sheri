#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'This template creates an Amazon EFS file system and mount target and associates it with Amazon EC2 instances in an Auto Scaling group. **WARNING** This template creates Amazon EC2 instances and related resources. You will be billed for the AWS resources used if you create a stack from this template.'

  parameter 'VolumeName',
            :Description => 'The name to be used for the EFS volume',
            :Type => 'String',
            :MinLength => '1',
            :Default => 'myvolume'

  resource 'MyEC2Instance', :Type => 'AWS::EC2::Instance', :Properties => {
      :InstanceType => 't2.micro',
      :ImageId => 'ami-00f07917',
      :KeyName => 'chef-dk',
	  :VpcId => 'vpc-ca10dfad',
      :CidrBlock => '10.0.1.0/24',
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
      :VpcId => 'vpc-ca10dfad',
      :CidrBlock => '10.0.1.0/24',
      :Tags => [
          {
              :Key => 'Application',
              :Value => aws_stack_id,
          },
      ],
  }

  resource 'InstanceSecurityGroup', :Type => 'AWS::EC2::SecurityGroup', :Properties => {
      :VpcId => 'vpc-ca10dfad',
      :GroupDescription => 'Enable SSH access via port 122',
      :SecurityGroupIngress => [
          {
              :IpProtocol => 'tcp',
              :FromPort => '122',
              :ToPort => '122',
              :CidrIp => ref('SSHLocation'),
          },
          { :IpProtocol => 'tcp', :FromPort => '80', :ToPort => '80', :CidrIp => '0.0.0.0/0' },
		  { :IpProtocol => 'tcp', :FromPort => '8443', :ToPort => '8443', :CidrIp => '0.0.0.0/0' },
		  { :IpProtocol => 'tcp', :FromPort => '8080', :ToPort => '8080', :CidrIp => '0.0.0.0/0' },
		  { :IpProtocol => 'udp', :FromPort => '1194', :ToPort => '1194', :CidrIp => '0.0.0.0/0' },
		  { :IpProtocol => 'udp', :FromPort => '161', :ToPort => '161', :CidrIp => '0.0.0.0/0' },
		  { :IpProtocol => 'tcp', :FromPort => '443', :ToPort => '443', :CidrIp => '0.0.0.0/0' },
		  { :IpProtocol => 'tcp', :FromPort => '22', :ToPort => '22', :CidrIp => '0.0.0.0/0' },
		  { :IpProtocol => 'tcp', :FromPort => '9418', :ToPort => '9418', :CidrIp => '0.0.0.0/0' },
		  { :IpProtocol => 'tcp', :FromPort => '25', :ToPort => '25', :CidrIp => '0.0.0.0/0' },
      ],
  }
end.exec!
