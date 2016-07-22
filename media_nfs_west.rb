#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

require '../../lib/autoloader.rb'

# Variables
Application='media_nfs_west'
Chef_attribute_directory=Application.downcase
APPLICATION_CLEAN = Application.gsub(/[^\p{Alnum}]/, '')
tier='web'
time = Time.now
timestamp = "#{time.day}-#{time.month}-#{time.year}"
iam_policies = [ '../../lib/common/iam_policies/optional/github-read-only-key.rb' ]
user_data_scripts = [
  "#{COMMON_DIRECTORY}/userdata/00-start.sh",
  "#{COMMON_DIRECTORY}/userdata/05-installChef.sh",
  "#{COMMON_DIRECTORY}/userdata/07-chefAttributesSync.sh",
  './userdata/10-chefAliases.sh',
  "#{COMMON_DIRECTORY}/userdata/15-runChef.sh",
  "#{COMMON_DIRECTORY}/userdata/100-end.sh"
]

template do
  load_from_file './parameters.rb'
  load_from_file "#{LIB_DIRECTORY}/common.rb"
  load_from_file "#{COMMON_DIRECTORY}/mappings/optional/jenkinsCI.rb"

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => "AWS Cloudformation template for the creation of a #{Application} environment within a VPC."

  # Tags - These tags are added to ALL resources in the stack
  tag :Environment, :Value => parameters['Environment'], :Immutable => true
  tag :Application, :Value =>  Application, :Immutable => true
  tag :CreatedBy, :Value =>  ENV['USER'], :Immutable => true
  tag :Tier, :Value =>  tier, :Immutable => true
  tag :Name, :Value =>  "#{Application}-#{parameters['Environment']}-#{timestamp}", :Immutable => true
  
  ###IAM role needs to be updated#############
  resource 'InstanceProfile', :Type => 'AWS::IAM::InstanceProfile', :Properties => {
      :Path => '/',
      :Roles => [ 'chef-manager-route-53' ],
  }
  
   # Take the requested policies from iam_policies and build them up to one big IAM role
 # combine_iam_policies(iam_policies)
  
  #Below section for SSL Cert mapping and needs to be updated
   mapping 'EnvironmentConfigs',
          :production => { :CERT => 'arn:aws:iam::080250996547:server-certificate/media_shopatron_com_with_chain' },
          :staging => { :CERT => 'arn:aws:iam::080250996547:server-certificate/media_shopatron_com_with_chain' },
          :development => { :CERT => 'arn:aws:iam::080250996547:server-certificate/media_shopatron_com_with_chain' },
          :devops => { :CERT => 'arn:aws:iam::080250996547:server-certificate/media_shopatron_com_with_chain' },
          :qa => { :CERT => 'arn:aws:iam::080250996547:server-certificate/media_shopatron_com_with_chain' }

  resource 'EC2SecurityGroupMedia', :Type => 'AWS::EC2::SecurityGroup', :Properties => {
      :GroupDescription => 'Enable SSH access via port 22 and http via port 80 from the load balancer.',
      :Tags => [
          {
              :Key => 'Environment',
              :Value => ref('Environment'),
          },
          { :Key => 'Application', :Value => 'Media' },
          {
              :Key => 'Name',
              :Value => join('', aws_stack_name, '_server'),
          },
      ],
      :SecurityGroupIngress => [
          { :IpProtocol => 'tcp', :FromPort => '22', :ToPort => '22', :CidrIp => '172.20.16.0/22' },
          { :IpProtocol => 'tcp', :FromPort => '22', :ToPort => '22', :CidrIp => '172.20.20.0/22' },
          {
              :IpProtocol => 'tcp',
              :FromPort => '80',
              :ToPort => '80',
              :SourceSecurityGroupId => ref('ElasticLoadBalancerSecurityGroup'),
          },
      ],
      :SecurityGroupEgress => [
          { :IpProtocol => 'tcp', :FromPort => '0', :ToPort => '65535', :CidrIp => '0.0.0.0/0' },
          { :IpProtocol => 'udp', :FromPort => '0', :ToPort => '65535', :CidrIp => '0.0.0.0/0' },
      ],
      :VpcId => find_in_map('RegionToVPC', aws_region, ref('Environment')),
  }
  
  resource 'EC2SecurityGroupNFS', :Type => 'AWS::EC2::SecurityGroup', :Properties => {
      :GroupDescription => 'Enable SSH access via port 22 and NFS access from Media servers.',
      :Tags => [
          {
              :Key => 'Environment',
              :Value => ref('Environment'),
          },
          { :Key => 'Application', :Value => 'Media' },
          {
              :Key => 'Name',
              :Value => join('', aws_stack_name, '_server'),
          },
      ],
      :SecurityGroupIngress => [
          { :IpProtocol => 'tcp', :FromPort => '22', :ToPort => '22', :CidrIp => '172.20.16.0/22' },
          { :IpProtocol => 'tcp', :FromPort => '22', :ToPort => '22', :CidrIp => '172.20.20.0/22' },
          {
              :IpProtocol => 'tcp',
              :FromPort => '22',
              :ToPort => '22',
              :SourceSecurityGroupId => ref('EC2SecurityGroupMedia'),
          },
          {
              :IpProtocol => 'tcp',
              :FromPort => '111',
              :ToPort => '111',
              :SourceSecurityGroupId => ref('EC2SecurityGroupMedia'),
          },
          {
              :IpProtocol => 'udp',
              :FromPort => '111',
              :ToPort => '111',
              :SourceSecurityGroupId => ref('EC2SecurityGroupMedia'),
          },
          {
              :IpProtocol => 'tcp',
              :FromPort => '2049',
              :ToPort => '2049',
              :SourceSecurityGroupId => ref('EC2SecurityGroupMedia'),
          },
          {
              :IpProtocol => 'udp',
              :FromPort => '32806',
              :ToPort => '32806',
              :SourceSecurityGroupId => ref('EC2SecurityGroupMedia'),
          },
      ],
      :SecurityGroupEgress => [
          { :IpProtocol => 'tcp', :FromPort => '0', :ToPort => '65535', :CidrIp => '0.0.0.0/0' },
          { :IpProtocol => 'udp', :FromPort => '0', :ToPort => '65535', :CidrIp => '0.0.0.0/0' },
      ],
      :VpcId => find_in_map('RegionToVPC', aws_region, ref('Environment')),
  }
  resource 'ElasticLoadBalancerSecurityGroup', :Type => 'AWS::EC2::SecurityGroup', :Properties => {
      :GroupDescription => 'Public ELB Security Group with HTTP access on port 80 and 443 from the internet',
      :Tags => [
          {
              :Key => 'Environment',
              :Value => ref('Environment'),
          },
          { :Key => 'Application', :Value => 'Media' },
          {
              :Key => 'Name',
              :Value => join('', aws_stack_name, '_server'),
          },
      ],
      :SecurityGroupIngress => [
          { :IpProtocol => 'tcp', :FromPort => '80', :ToPort => '80', :CidrIp => '0.0.0.0/0' },
          { :IpProtocol => 'tcp', :FromPort => '443', :ToPort => '443', :CidrIp => '0.0.0.0/0' },
      ],
      :SecurityGroupEgress => [
          { :IpProtocol => 'tcp', :FromPort => '80', :ToPort => '80', :CidrIp => '0.0.0.0/0' },
          { :IpProtocol => 'tcp', :FromPort => '443', :ToPort => '443', :CidrIp => '0.0.0.0/0' },
      ],
      :VpcId => find_in_map('RegionToVPC', aws_region, ref('Environment')),
  }
  
  resource 'ElasticLoadBalancer', :Type => 'AWS::ElasticLoadBalancing::LoadBalancer', :Properties => {
      :CrossZone => true,
      :AccessLoggingPolicy => {
          :EmitInterval => '5',
          :Enabled => true,
          :S3BucketName => join('', 'shopatron-elb-access-logs-', aws_region),
          :S3BucketPrefix => join('', "#{APPLICATION_CLEAN}/", ref('Environment'), '/', aws_stack_name, '/external'),
      },
      :ConnectionDrainingPolicy => {
          :Enabled => true,
          :Timeout => '30',
      },
      :HealthCheck => {
          :HealthyThreshold => '3',
          :Interval => '30',
          :Target => join('', 'HTTP:', '80', '/media/check.txt'),
          :Timeout => '5',
          :UnhealthyThreshold => '5',
      },
      :Listeners => [
          {
              :InstancePort => '80',
              :InstanceProtocol => 'HTTP',
              :LoadBalancerPort => '443',
              :Protocol => 'HTTPS',
              :SSLCertificateId => find_in_map('EnvironmentConfigs', ref('Environment'), 'CERT'),
          },
          { :InstancePort => '80', :InstanceProtocol => 'HTTP', :LoadBalancerPort => '80', :Protocol => 'HTTP' },
      ],
      :SecurityGroups => [ ref('ElasticLoadBalancerSecurityGroup') ],
      :Subnets => find_in_map('RegionToTier', find_in_map('RegionToSubnet', aws_region, ref('Environment')), 'pub'),
  }
  #NFS Server part need some tuning and it may be removed based on EFS implementaton 
  resource 'NFS', :Type => 'AWS::EC2::Instance', :Properties => {
      :IamInstanceProfile => ref('InstanceProfile'),
      :ImageId => find_in_map('AWSRegionToAMI', aws_region, 'ami'),
      :InstanceType => ref('InstanceType'),
      :KeyName => 'shopatrondevops',
      :SecurityGroupIds => [ ref('EC2SecurityGroupNFS'),
			     find_in_map('RegEnvDevOpsSecurityGroup', aws_region, ref('Environment')), ],
      #:SubnetId => find_in_map('RegionToTier', find_in_map('RegionToSubnet', aws_region, ref('Environment')), 'pub'),
      :SubnetId => 'subnet-555dba0d',
      #:UserData => base64(interpolate(combine_user_data(user_data_scripts))),
            :UserData => base64(
          join('',
               "#!/bin/bash\n",
               "function error_exit\n",
               "{\n",
               ' /opt/aws/bin/cfn-signal -e 1 -r "$1" \'',
               ref('WaitHandleNFS'),
               "'\n",
               " exit 1\n",
               "}\n",
               "# Chef install/update.\n",
               "cat <<'EOF' >> /root/chef-check.sh\n",
               "#!/bin/bash\n",
               "VERSION=\"11.16.4\"\n",
               "if rpm -qa | grep chef | grep $VERSION; then\n",
               "   exit\n",
               "elif rpm -qa | grep chef | grep -v $VERSION; then\n",
               "   rpm -e chef && curl -L \"http://www.opscode.com/chef/download?p=el&pv=6&m=x86_64&v=$VERSION\" -o chef-install && rpm -Uvh chef-install\n",
               "else\n",
               "   curl -L \"http://www.opscode.com/chef/download?p=el&pv=6&m=x86_64&v=$VERSION\" -o chef-install && rpm -Uvh chef-install\n",
               "fi\n",
               "EOF\n",
               "chmod 755 /root/chef-check.sh\n",
               "/root/chef-check.sh > /tmp/chef_install.log 2>&1 || error_exit 'Failed to install chef.'\n",
               "INSTANCEID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`\n",
               'NODE_NAME="',
               aws_stack_name,
               '-$INSTANCEID',
               "\"\n",
               "mkdir /etc/chef\n",
               "cat > /etc/chef/client.rb << EOF\n",
               "ssl_verify_mode :verify_peer\n",
               "log_level       :info\n",
               "log_location     \"/var/log/chef-client.log\"\n",
               "\n",
               "chef_server_url  \"https://api.opscode.com/organizations/sptron\"\n",
               'environment "',
               ref('Environment'),
               "\"\n",
               'node_name "',
               '$NODE_NAME',
               "\"\n",
               "validation_client_name \"sptron-validator\"\n",
               "# Using default node name\n",
               "\n",
               "file_backup_path   \"/var/chef/backup\"\n",
               "file_cache_path    \"/var/chef/cache\"\n",
               "\n",
               "pid_file           \"/var/chef/cache/client.pid\"\n",
               "EOF\n",
               "# Node attributes to be seeded during first run\n",
               "cat > /etc/chef/roles.json << EOF\n",
               "{\n",
               '  "run_list": ["role[nfs_server]"',
               ', "media_nfs-shopatron"',
               ', "newrelic"',
               "],\n",
               "  \"cloud\": {\n",
               '    "aws_cfn_stack": "',
               aws_stack_name,
               "\", \n",
               '    "branch_from_template": "',
               ref('DeployBranch'),
               "\", \n",
               '    "region_from_template": "',
               aws_region,
               "\", \n",
               '    "read_only": "',
               ref('ReadOnly'),
               "\", \n",
               "    \"ec2_instance_name\": \"NFS\" \n",
               "  }, \n",
               '  "loadbalancer_dnsname": "',
               join('', get_att('ElasticLoadBalancer', 'DNSName')),
               "\"\n",
               "}\n",
               "EOF\n",
               "# Create Chef key file\n",
               "cat > /etc/chef/validation.pem << EOF\n",
               "-----BEGIN RSA PRIVATE KEY-----\n",
               "MIIEogIBAAKCAQEAyR63x++87IZYtMvXLGyJ13XGcjHPoi89PeTmpmXFip9mwFcS\n",
               "2SP0UUXR0LjS+6TKlQs7Q+CqYhPGvNaEEkw5BbiMiSNtdqctDx+B9a0OiMkJoIG3\n",
               "KgFm25p9PTpLuhw29JE0yBOLIgd8i3mr4//Cjv6CZNKP35HQ8TacSBJAK6z/M7ev\n",
               "lSvd/vKjPBZBBTOYVMr/aH5lgn+25/sgkqKqB0AromrmJwYV01wkOW/GVNoC6SZL\n",
               "ayELZ4J/tMbhohxKuUHFtHzL2tpth/wXJVrwdz3+/SJUuqegk8kszoijLTSiRr0F\n",
               "hcTSRMtv6k7eduwPTDj32ZHlr6v/5mhGpWgYrQIDAQABAoIBAF59zyzhpyqdaDnx\n",
               "d3QIvq57SDRI0NvLRAO7ct6E/E3H3JfLkTBx4wz4N77Px1ixsPhboYmfmY2g6wO3\n",
               "6a9LHpNghK699WUE4He1fvK1TxnXEm3V4/+ZTwEoUWUd6YxUS0GWo2zJOdpQGCTT\n",
               "kn35oShbzVmfUDdjI/7ggIagBIQ/2yI0GK7QurvFFVv2ij/nmpBPsOhhkDaTAZJ8\n",
               "NTFNllMQPe6hsA9NIEOHwR6AdmpTtw+ObP2vZDopD+s5ZIA4DSHLnwlvhbD3h9S/\n",
               "dkPcoAVDxXLcMimmeC6rlxpZBPasYDUeaeNVAUwmvT3/18O+lsIR9ISqsj7MvNsz\n",
               "b2Qd1YECgYEA5JHy65gGN4mCwO14nZ4ugPEP+JjbBfamKc5Qmt/YxdXZ3Ab3BhKL\n",
               "OQpgY8pOFULkAYgNiwCOpE4LUcK1Rgt7BHZ6bigkTUj9cxcKiVkYKR2oolO/pqqS\n",
               "T5+Q3qD7Lz1wIbiql3BGPtoERo+hbY2rx3jQZ84fEaN+ekupScy4peECgYEA4UF0\n",
               "ufzaRzdj6z6P4o2B1R5Se6pYbuJ7KOcZ+caeoLfvGmogzZ9shjJIFAWphSX/NLVZ\n",
               "EKnKDMMSNlDFteGAmNikiDw3xv1wDoR4kzdMN1mvWJDcnVYKk2Y1WPH7Gu2epiOU\n",
               "YS68qzPWhdN0u4Ah/PGCCEDdbsLH6vzCPey8tE0CgYAql1egtu9RofoPYTC8jiE0\n",
               "PbcwJ6uIbPGBkMRMV7HZC4RRD6swInx24IwdjDEInTJHZsa/RBdQXoqVbabBqpn9\n",
               "tuYRaMF69ULlE0IPXd62qqQlu11W/SnOVHl2QqELqHMglXyUQ4OTaqSpUVJPS7ra\n",
               "rJSJA0ueycxjlX2yFsfBgQKBgF/QvPskECE88XauXPvsX26tAD70PbulAOhsLUNu\n",
               "9ii9NKrSu/NbPglzN++0XOBzQjREc4dAAd8d1xBdmUv9iPr7JDmDC+LMCS9TsApG\n",
               "+leNAaY1sHIImGUMk+Kqw7o3m0VmWwZfoAde/IBeawgav9pdTIeAN/CWT/2n2GQI\n",
               "4Ff9AoGAK7wyyP5A7OKjPCMhly1uN4InhBuECpsi3XHFWg07EMYbeGynmF00h6Pb\n",
               "4ljUxrI37NPOvMSdAov0Yyd5HSnK0L1Xu6bHVT6gMIUdoEBqgMKlJ6hornAng5BK\n",
               "v3bc2kiCO3P7k16it1c8QehG0NvZmHMW8a2hm3RTcuAms6oD6Zk=\n",
               "-----END RSA PRIVATE KEY-----\n",
               "EOF\n",
               "# Ohai hint to detect as EC2 node in VPC (on first run as opposed to second)\n",
               "mkdir -p /etc/chef/ohai/hints\n",
               "touch /etc/chef/ohai/hints/ec2.json\n",
               "# Chef firstrun\n",
               'chef-client',
               ' -j /etc/chef/roles.json',
               ' -E ',
               ref('Environment'),
               ' $NODE_NAME',
               " 2>&1 || error_exit 'Failed to initialize host via chef client' \n",
               '/opt/aws/bin/cfn-signal -e $? \'',
               ref('WaitHandleNFS'),
               "'\n",
          )
      ),
  }
    resource "#{APPLICATION_CLEAN}", :Type => 'AWS::AutoScaling::AutoScalingGroup', :Properties => {
      :NotificationConfiguration => {
          :TopicARN => find_in_map('TerminationSNSTopic2Region', aws_region, 'Topic'),
          :NotificationTypes => [ 'autoscaling:EC2_INSTANCE_TERMINATE' ],
      },
      :DesiredCapacity => ref('DesiredCapacity'),
      :LaunchConfigurationName => ref('LaunchConfig'),
      :LoadBalancerNames => [ ref('ElasticLoadBalancer') ],
      :MaxSize => ref('AutoScalingMaxSize'),
      :MinSize => ref('DesiredCapacity'),
      :Tags => [
          {
              :Key => 'Environment',
              :Value => ref('Environment'),
              :PropagateAtLaunch => 'true',
          },
          { :Key => 'Tier', :Value => 'web', :PropagateAtLaunch => 'true' },
          {
              :Key => 'Name',
              :Value => join('', aws_stack_name, '-web', '_server'),
              :PropagateAtLaunch => 'true',
          },
      ],
      :VPCZoneIdentifier => find_in_map('RegionToTier', find_in_map('RegionToSubnet', aws_region, ref('Environment')), 'web'),
  }
  resource 'LaunchConfig', :Type => 'AWS::AutoScaling::LaunchConfiguration', :Properties => {
      :AssociatePublicIpAddress => false,
      :IamInstanceProfile => ref('InstanceProfile'),
      :ImageId => find_in_map('AWSRegionToAMI', aws_region, 'ami'),
      :InstanceType => ref('InstanceType'),
      :KeyName => 'shopatrondevops',
      :SecurityGroups => [
          ref('EC2SecurityGroupMedia'),
	  find_in_map('RegEnvDevOpsSecurityGroup', aws_region, ref('Environment')),
      ],
      :UserData => base64(interpolate(combine_user_data(user_data_scripts))),
  }
  #some tweaks requrired on wait condition
  resource 'WaitHandleNFS', :Type => 'AWS::CloudFormation::WaitConditionHandle'

  resource 'WaitConditionNFS', :Type => 'AWS::CloudFormation::WaitCondition', :DependsOn => 'NFS', :Properties => {
      :Count => '1',
      :Handle => ref('WaitHandleNFS'),
      :Timeout => '3600',
  }

  resource 'WaitHandle', :Type => 'AWS::CloudFormation::WaitConditionHandle'

  resource 'WaitCondition', :Type => 'AWS::CloudFormation::WaitCondition', :DependsOn => "#{APPLICATION_CLEAN}", :Properties => {
      :Count => ref('DesiredCapacity'),
      :Handle => ref('WaitHandle'),
      :Timeout => '1500',
  }
  
  resource 'ScaleUpPolicy', :Type => 'AWS::AutoScaling::ScalingPolicy', :Properties => {
      :AdjustmentType => 'ChangeInCapacity',
      :AutoScalingGroupName => ref("#{APPLICATION_CLEAN}"),
      :Cooldown => '360',
      :ScalingAdjustment => '1',
  }

  resource 'ScaleDownPolicy', :Type => 'AWS::AutoScaling::ScalingPolicy', :Properties => {
      :AdjustmentType => 'ChangeInCapacity',
      :AutoScalingGroupName => ref("#{APPLICATION_CLEAN}"),
      :Cooldown => '300',
      :ScalingAdjustment => '-1',
  }
#NFS Server alert
  resource 'CPUAlarmHighNFS', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alert if CPU > 90% for 15 minutes',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'AutoScalingGroupName',
              :Value => ref('NFS'),
          },
      ],
      :EvaluationPeriods => '3',
      :MetricName => 'CPUUtilization',
      :Namespace => 'AWS/EC2',
      :Period => '300',
      :Statistic => 'Average',
      :Threshold => '90',
  }
  resource 'CPUAlarmHigh', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [
          find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')),
          ref('ScaleUpPolicy'),
      ],
      :AlarmDescription => 'Scale-up if CPU > 60% for 10 minutes',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'AutoScalingGroupName',
              :Value => ref("#{APPLICATION_CLEAN}"),
          },
      ],
      :EvaluationPeriods => '3',
      :MetricName => 'CPUUtilization',
      :Namespace => 'AWS/EC2',
      :Period => '300',
      :Statistic => 'Average',
      :Threshold => '60',
  }

  resource 'CPUAlarmLow', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ ref('ScaleDownPolicy') ],
      :AlarmDescription => 'Scale-down if CPU < 40% for 15 minutes',
      :ComparisonOperator => 'LessThanThreshold',
      :Dimensions => [
          {
              :Name => 'AutoScalingGroupName',
              :Value => ref("#{APPLICATION_CLEAN}"),
          },
      ],
      :EvaluationPeriods => '3',
      :MetricName => 'CPUUtilization',
      :Namespace => 'AWS/EC2',
      :Period => '300',
      :Statistic => 'Average',
      :Threshold => '40',
  }
  
  resource 'TooMany500ErrorsExternalELB', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alarm if there are too many 500 errors on external ELB.',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'LoadBalancerName',
              :Value => ref('ElasticLoadBalancer'),
          },
      ],
      :EvaluationPeriods => '5',
      :MetricName => 'HTTPCode_Backend_5XX',
      :Namespace => 'AWS/ELB',
      :Period => '60',
      :Statistic => 'Sum',
      :Threshold => '150',
  }

  resource 'TooManyELB4XXExternalELB', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alarm if there are too many 4XX erros from external ELB.',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'LoadBalancerName',
              :Value => ref('ElasticLoadBalancer'),
          },
      ],
      :EvaluationPeriods => '5',
      :MetricName => 'HTTPCode_ELB_4XX',
      :Namespace => 'AWS/ELB',
      :Period => '60',
      :Statistic => 'Sum',
      :Threshold => '150',
  }

  resource 'TooManyELB5XXExternalELB', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alarm if there are too many 5XX erros from external ELB.',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'LoadBalancerName',
              :Value => ref('ElasticLoadBalancer'),
          },
      ],
      :EvaluationPeriods => '5',
      :MetricName => 'HTTPCode_ELB_5XX',
      :Namespace => 'AWS/ELB',
      :Period => '60',
      :Statistic => 'Sum',
      :Threshold => '150',
  }

  resource 'TooManyBackend3XXExternalELB', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alarm if there are too many 3XX errors from backend instances in external ELB.',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'LoadBalancerName',
              :Value => ref('ElasticLoadBalancer'),
          },
      ],
      :EvaluationPeriods => '5',
      :MetricName => 'HTTPCode_Backend_3XX',
      :Namespace => 'AWS/ELB',
      :Period => '60',
      :Statistic => 'Sum',
      :Threshold => '150',
  }

  resource 'TooManyBackend4XXExternalELB', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alarm if there are too many 4XX errors from backend instances in external ELB.',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'LoadBalancerName',
              :Value => ref('ElasticLoadBalancer'),
          },
      ],
      :EvaluationPeriods => '5',
      :MetricName => 'HTTPCode_Backend_4XX',
      :Namespace => 'AWS/ELB',
      :Period => '60',
      :Statistic => 'Sum',
      :Threshold => '150',
  }

  resource 'BackendConnectionErrorsExternalELB', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alarm if there are too many BackendConnectionErrors on external ELB.',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'LoadBalancerName',
              :Value => ref('ElasticLoadBalancer'),
          },
      ],
      :EvaluationPeriods => '5',
      :MetricName => 'BackendConnectionErrors',
      :Namespace => 'AWS/ELB',
      :Period => '60',
      :Statistic => 'Sum',
      :Threshold => '150',
  }

  resource 'SurgeQueueLengthExternalELB', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alarm if there are too many SurgeQueueLength on external ELB.',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'LoadBalancerName',
              :Value => ref('ElasticLoadBalancer'),
          },
      ],
      :EvaluationPeriods => '5',
      :MetricName => 'SurgeQueueLength',
      :Namespace => 'AWS/ELB',
      :Period => '60',
      :Statistic => 'Maximum',
      :Threshold => '5',
  }

  resource 'SpilloverCountExternalELB', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alarm if there are too many SpilloverCount on external ELB.',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'LoadBalancerName',
              :Value => ref('ElasticLoadBalancer'),
          },
      ],
      :EvaluationPeriods => '5',
      :MetricName => 'SpilloverCount',
      :Namespace => 'AWS/ELB',
      :Period => '60',
      :Statistic => 'Sum',
      :Threshold => '1',
  }

  resource 'TooManyUnhealthyHostsAlarm', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alarm if there are any unhealthy hosts.',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'LoadBalancerName',
              :Value => ref('ElasticLoadBalancer'),
          },
      ],
      :EvaluationPeriods => '4',
      :MetricName => 'UnHealthyHostCount',
      :Namespace => 'AWS/ELB',
      :Period => '300',
      :Statistic => 'Average',
      :Threshold => '1',
  }

  resource 'RequestLatencyAlarmHigh', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')) ],
      :AlarmDescription => 'Alarm if request latency > ',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'LoadBalancerName',
              :Value => ref('ElasticLoadBalancer'),
          },
      ],
      :EvaluationPeriods => '4',
      :MetricName => 'Latency',
      :Namespace => 'AWS/ELB',
      :Period => '300',
      :Statistic => 'Average',
      :Threshold => '3',
  }
  
  output 'MediaWebsiteURL',
         :Description => 'URL for the Media site.',
         :Value => join('', 'http://', get_att('ElasticLoadBalancer', 'DNSName'))

end.exec!
