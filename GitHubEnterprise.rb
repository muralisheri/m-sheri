#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

user_data_scripts = [
   '/home/ec2-user/code/m-sheri/m-sheri/10-chefAliases.sh',
]

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'Ec2 block device mapping'
  parameter 'VolumeName',
            :Description => 'The name to be used for the EFS volume',
            :Type => 'String',
            :MinLength => '1',
            :Default => 'myEFSvolume'
			
  puts 'VolumeName parameter set...'			
			
  parameter 'MountPoint',
            :Description => 'The Linux mount point for the EFS volume',
            :Type => 'String',
            :MinLength => '1',
            :Default => 'myEFSvolume'
			
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
	
  puts 'MyEC2Instance resource done...'
	
  resource 'FileSystem', :Type => 'AWS::EFS::FileSystem', :Properties => {
      :FileSystemTags => [
          {
              :Key => 'Name',
              :Value => ref('VolumeName'),
          },
      ],
  }
  puts 'FileSystem resource done...'
  
  resource 'MountTarget', :Type => 'AWS::EFS::MountTarget', :Properties => {
      :FileSystemId => ref('FileSystem'),
      :SubnetId => 'subnet-d304d8a4',
	  :SecurityGroups => [ 'sg-2cf4df49' ],
  }
end.exec!