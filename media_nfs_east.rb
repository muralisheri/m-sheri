#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'AWS Cloudformation template for the creation of the Shopatron Media application within a VPC.'

  parameter 'DeployBranch',
            :Default => 'master',
            :Description => 'The branch of the Media app to be deployed',
            :Type => 'String'

  parameter 'Environment',
            :Default => 'devops',
            :Description => 'The environment where the nodes should register',
            :Type => 'String',
            :AllowedValues => [ 'devops', 'development', 'qa', 'staging', 'production' ],
            :ConstraintDescription => 'Must be a valid Chef Environment.'

  parameter 'MediaAutoScalingMinSize',
            :Type => 'Number',
            :Description => 'Minimum number of Media nodes in the tier.',
            :Default => '2'

  parameter 'MediaAutoScalingMaxSize',
            :Type => 'Number',
            :Description => 'Maximum number of Media nodes in the tier.',
            :Default => '6'

  parameter 'MediaDesiredCapacity',
            :Default => '2',
            :Description => 'The initial number of Media nodes to deploy.',
            :Type => 'Number',
            :MinValue => '1',
            :MaxValue => '6',
            :ConstraintDescription => 'Must be between 2 and 6 EC2 instances.'

  parameter 'InstanceTypeMedia',
            :Description => 'Media server EC2 instance type.',
            :Type => 'String',
            :Default => 'm1.medium',
            :AllowedValues => [ 'm1.medium', 'm1.large', 'm1.xlarge', 'm2.xlarge', 'm2.2xlarge', 'm2.4xlarge', 'c1.medium', 'c1.xlarge' ],
            :ConstraintDescription => 'Must be a valid EC2 instance type.'

  parameter 'InstanceTypeNFS',
            :Description => 'NFS server EC2 instance type.',
            :Type => 'String',
            :Default => 'm1.medium',
            :AllowedValues => [ 'm1.medium', 'm1.large', 'm1.xlarge', 'm2.xlarge', 'm2.2xlarge', 'm2.4xlarge', 'c1.medium', 'c1.xlarge' ],
            :ConstraintDescription => 'Must be a valid EC2 instance type.'

  parameter 'ReadOnly',
            :Type => 'String',
            :Description => 'Whether or not to deploy the application as read only.',
            :Default => 'true',
            :AllowedValues => [ 'true', 'false' ],
            :ConstraintDescription => 'Must be either true or false'

  mapping 'AWSInstanceType2Arch',
          :'m1.medium' => { :Arch => '64' },
          :'m1.large' => { :Arch => '64' },
          :'m1.xlarge' => { :Arch => '64' },
          :'m2.xlarge' => { :Arch => '64' },
          :'m2.2xlarge' => { :Arch => '64' },
          :'m2.4xlarge' => { :Arch => '64' },
          :'c1.medium' => { :Arch => '64' },
          :'c1.xlarge' => { :Arch => '64' }

  mapping 'TerminationSNSTopic2Region',
          :'us-east-1' => { :Topic => 'arn:aws:sns:us-east-1:080250996547:chef-unregister' },
          :'us-west-2' => { :Topic => 'arn:aws:sns:us-west-2:080250996547:chef-unregister' }

  mapping 'RegionEnvToSNSTopic',
          :'us-west-2' => {
              :production => 'arn:aws:sns:us-west-2:080250996547:Shopatron-Production-West',
              :development => 'arn:aws:sns:us-west-2:080250996547:Shopatron-Development-West',
              :devops => 'arn:aws:sns:us-west-2:080250996547:Shopatron-Devops-West',
              :qa => 'arn:aws:sns:us-west-2:080250996547:Shopatron-QA-West',
              :staging => 'arn:aws:sns:us-west-2:080250996547:Shopatron-Staging-West',
          },
          :'us-east-1' => {
              :production => 'arn:aws:sns:us-east-1:080250996547:Shopatron-Production-East',
              :development => 'arn:aws:sns:us-east-1:080250996547:Shopatron-Development-East',
              :devops => 'arn:aws:sns:us-east-1:080250996547:Shopatron-Devops-East',
              :qa => 'arn:aws:sns:us-east-1:080250996547:Shopatron-QA-East',
              :staging => 'arn:aws:sns:us-east-1:080250996547:Shopatron-Staging-East',
          }

  mapping 'AWSRegionArch2BaseAMI',
          :'us-east-1' => { :'64' => 'ami-e19a488a' },
          :'us-west-1' => { :'64' => 'ami-9f1807da' },
          :'us-west-2' => { :'64' => 'ami-31dfd201' },
          :'eu-west-1' => { :'64' => 'ami-a54ccbd2' },
          :'ap-southeast-1' => { :'64' => 'ami-33c7ee61' },
          :'ap-northeast-1' => { :'64' => 'ami-5ef9ef5f' }

  resource 'InstanceProfile', :Type => 'AWS::IAM::InstanceProfile', :Properties => {
      :Path => '/',
      :Roles => [ 'chef-manager-route-53' ],
  }

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
      :VpcId => 'vpc-067fe468',
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
      :VpcId => 'vpc-067fe468',
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
      :VpcId => 'vpc-067fe468',
  }

  resource 'ElasticLoadBalancer', :Type => 'AWS::ElasticLoadBalancing::LoadBalancer', :Properties => {
      :Tags => [
          {
              :Key => 'Environment',
              :Value => ref('Environment'),
          },
          { :Key => 'Application', :Value => 'Media' },
          {
              :Key => 'Version',
              :Value => ref('DeployBranch'),
          },
      ],
      :HealthCheck => {
          :HealthyThreshold => '3',
          :Interval => '30',
          :Target => join('', 'HTTP:', '80', '/media/check.txt'),
          :Timeout => '5',
          :UnhealthyThreshold => '5',
      },
      :Listeners => [
          { :InstancePort => '80', :LoadBalancerPort => '80', :Protocol => 'HTTP' },
          {
              :InstancePort => '80',
              :LoadBalancerPort => '443',
              :Protocol => 'HTTPS',
              :SSLCertificateId => 'arn:aws:iam::080250996547:server-certificate/media_shopatron_com_with_chain',
          },
      ],
      :SecurityGroups => [ ref('ElasticLoadBalancerSecurityGroup') ],
      :Subnets => [ 'subnet-f00f4b9e' ],
  }

  resource 'NFS', :Type => 'AWS::EC2::Instance', :Properties => {
      :AvailabilityZone => 'us-east-1a',
      :IamInstanceProfile => ref('InstanceProfile'),
      :ImageId => find_in_map('AWSRegionArch2BaseAMI', aws_region, find_in_map('AWSInstanceType2Arch', ref('InstanceTypeNFS'), 'Arch')),
      :InstanceType => ref('InstanceTypeNFS'),
      :KeyName => 'shopatrondevops',
      :SecurityGroupIds => [ ref('EC2SecurityGroupNFS') ],
      :SubnetId => 'subnet-f4b12b9a',
      :Tags => [
          {
              :Key => 'Environment',
              :Value => ref('Environment'),
              :PropagateAtLaunch => 'true',
          },
          { :Key => 'Application', :Value => 'Media', :PropagateAtLaunch => 'true' },
          {
              :Key => 'Name',
              :Value => join('', aws_stack_name, '-nfs_server'),
              :PropagateAtLaunch => 'true',
          },
      ],
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
               "cat > /root/chef-check.sh << EOF\n",
               "#!/bin/bash\n",
               "if rpm -qa | grep chef | grep 11.12.8-1; then\n",
               "   exit\n",
               "elif rpm -qa | grep chef | grep -v 11.12.8-1; then\n",
               "   rpm -e chef && curl -L 'http://www.opscode.com/chef/download?p=el&pv=6&m=x86_64&v=11.12.8' -o chef-install && rpm -Uvh chef-install\n",
               "else\n",
               "   curl -L 'http://www.opscode.com/chef/download?p=el&pv=6&m=x86_64&v=11.12.8' -o chef-install && rpm -Uvh chef-install\n",
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
               "# Add an alias for running the chef-client if needed\n",
               "echo \"#!/bin/bash\n\nsudo chef-client -L /var/log/chef-client.log -j /etc/chef/roles.json -N $NODE_NAME",
               "\" >> /usr/local/bin/rcc\n",
               "chmod +x /usr/local/bin/rcc\n",
               "echo \"alias rcc='/usr/local/bin/rcc'\">> /root/.bashrc\n",
               "# Ohai hint to detect as EC2 node in VPC (on first run as opposed to second)\n",
               "mkdir -p /etc/chef/ohai/hints\n",
               "touch /etc/chef/ohai/hints/ec2.json\n",
               "# Chef firstrun\n",
               'chef-client',
               ' -j /etc/chef/roles.json',
               ' -E ',
               ref('Environment'),
               ' -N $NODE_NAME',
               " > /tmp/chef_firstrun.log 2>&1 || error_exit 'Failed to initialize host via chef client' \n",
               '/opt/aws/bin/cfn-signal -e $? \'',
               ref('WaitHandleNFS'),
               "'\n",
          )
      ),
  }

  resource 'Media', :Type => 'AWS::AutoScaling::AutoScalingGroup', :Properties => {
      :AvailabilityZones => [ 'us-east-1a' ],
      :DesiredCapacity => ref('MediaDesiredCapacity'),
      :LaunchConfigurationName => ref('LaunchConfigMedia'),
      :NotificationConfiguration => {
          :TopicARN => find_in_map('TerminationSNSTopic2Region', aws_region, 'Topic'),
          :NotificationTypes => [ 'autoscaling:EC2_INSTANCE_TERMINATE' ],
      },
      :LoadBalancerNames => [ ref('ElasticLoadBalancer') ],
      :MaxSize => ref('MediaAutoScalingMaxSize'),
      :MinSize => ref('MediaAutoScalingMinSize'),
      :Tags => [
          {
              :Key => 'Environment',
              :Value => ref('Environment'),
              :PropagateAtLaunch => 'true',
          },
          { :Key => 'Application', :Value => 'Media', :PropagateAtLaunch => 'true' },
          {
              :Key => 'Name',
              :Value => join('', aws_stack_name, '-app_server'),
              :PropagateAtLaunch => 'true',
          },
      ],
      :VPCZoneIdentifier => [ 'subnet-f4b12b9a' ],
  }

  resource 'LaunchConfigMedia', :Type => 'AWS::AutoScaling::LaunchConfiguration', :Properties => {
      :AssociatePublicIpAddress => false,
      :IamInstanceProfile => ref('InstanceProfile'),
      :ImageId => find_in_map('AWSRegionArch2BaseAMI', aws_region, find_in_map('AWSInstanceType2Arch', ref('InstanceTypeMedia'), 'Arch')),
      :InstanceType => ref('InstanceTypeMedia'),
      :KeyName => 'shopatrondevops',
      :SecurityGroups => [ ref('EC2SecurityGroupMedia') ],
      :UserData => base64(
          join('',
               "#!/bin/bash\n",
               "function error_exit\n",
               "{\n",
               ' /opt/aws/bin/cfn-signal -e 1 -r "$1" \'',
               ref('WaitHandleMedia'),
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
               '  "run_list": ["role[media]"',
               ', "role[monitor]"',
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
               '    "nfs_server_ip": "',
               get_att('NFS', 'PrivateIp'),
               "\", \n",
               '    "read_only": "',
               ref('ReadOnly'),
               "\", \n",
               "    \"aws_autoscaling_group\": \"Media\" \n",
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
               "# Add an alias for running the chef-client if needed\n",
               "echo \"#!/bin/bash\n\nsudo chef-client -L /var/log/chef-client.log -j /etc/chef/roles.json -N $NODE_NAME",
               "\" >> /usr/local/bin/rcc\n",
               "chmod +x /usr/local/bin/rcc\n",
               "echo \"alias rcc='/usr/local/bin/rcc'\">> /root/.bashrc\n",
               "# Ohai hint to detect as EC2 node in VPC (on first run as opposed to second)\n",
               "mkdir -p /etc/chef/ohai/hints\n",
               "touch /etc/chef/ohai/hints/ec2.json\n",
               "# Chef firstrun\n",
               'chef-client',
               ' -j /etc/chef/roles.json',
               ' -E ',
               ref('Environment'),
               ' -N $NODE_NAME',
               " 2>&1 || error_exit 'Failed to initialize host via chef client' \n",
               '/opt/aws/bin/cfn-signal -e $? \'',
               ref('WaitHandleMedia'),
               "'\n",
          )
      ),
  }

  resource 'WaitHandleMedia', :Type => 'AWS::CloudFormation::WaitConditionHandle'

  resource 'WaitConditionMedia', :Type => 'AWS::CloudFormation::WaitCondition', :DependsOn => 'Media', :Properties => {
      :Count => ref('MediaDesiredCapacity'),
      :Handle => ref('WaitHandleMedia'),
      :Timeout => '3600',
  }

  resource 'WaitHandleNFS', :Type => 'AWS::CloudFormation::WaitConditionHandle'

  resource 'WaitConditionNFS', :Type => 'AWS::CloudFormation::WaitCondition', :DependsOn => 'NFS', :Properties => {
      :Count => '1',
      :Handle => ref('WaitHandleNFS'),
      :Timeout => '3600',
  }

  resource 'ScaleUpPolicy', :Type => 'AWS::AutoScaling::ScalingPolicy', :Properties => {
      :AdjustmentType => 'ChangeInCapacity',
      :AutoScalingGroupName => ref('Media'),
      :Cooldown => '360',
      :ScalingAdjustment => '1',
  }

  resource 'ScaleDownPolicy', :Type => 'AWS::AutoScaling::ScalingPolicy', :Properties => {
      :AdjustmentType => 'ChangeInCapacity',
      :AutoScalingGroupName => ref('Media'),
      :Cooldown => '300',
      :ScalingAdjustment => '-1',
  }

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

  resource 'CPUAlarmHighMedia', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [
          find_in_map('RegionEnvToSNSTopic', aws_region, ref('Environment')),
          ref('ScaleUpPolicy'),
      ],
      :AlarmDescription => 'Scale-up and alert if CPU > 60% for 10 minutes',
      :ComparisonOperator => 'GreaterThanThreshold',
      :Dimensions => [
          {
              :Name => 'AutoScalingGroupName',
              :Value => ref('Media'),
          },
      ],
      :EvaluationPeriods => '2',
      :MetricName => 'CPUUtilization',
      :Namespace => 'AWS/EC2',
      :Period => '300',
      :Statistic => 'Average',
      :Threshold => '60',
  }

  resource 'CPUAlarmLowMedia', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
      :AlarmActions => [ ref('ScaleDownPolicy') ],
      :AlarmDescription => 'Scale-down if CPU < 40% for 15 minutes',
      :ComparisonOperator => 'LessThanThreshold',
      :Dimensions => [
          {
              :Name => 'AutoScalingGroupName',
              :Value => ref('Media'),
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

  resource 'TooManyUnhealthyHostsAlarmMedia', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
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

  resource 'RequestLatencyAlarmHighMedia', :Type => 'AWS::CloudWatch::Alarm', :Properties => {
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
