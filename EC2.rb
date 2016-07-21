#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'Ec2 block device mapping'

  resource 'MyEC2Instance', :Type => 'AWS::EC2::Instance', :Properties => {
      :ImageId => 'ami-79fd7eee',
      :KeyName => 'testkey',
      :BlockDeviceMappings => [
          {
              :DeviceName => '/dev/sdm',
              :Ebs => { :VolumeType => 'gpp2', :DeleteOnTermination => 'false', :VolumeSize => '20' },
          },
          {
              :DeviceName => '/dev/sdk',
              :NoDevice => {},
          },
      ],
  }