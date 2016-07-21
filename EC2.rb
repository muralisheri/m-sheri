#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'Ec2 block device mapping'
 
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
  resource 'myVPC', :Type => 'AWS::EC2::VPC', :Properties => {
	  :CidrBlock => '10.0.0.0/24',
      :EnableDnsSupport => 'true',
      :EnableDnsHostnames => 'true',
      :InstanceTenancy => 'default',
  }
end.exec!