parameter 'ReadOnly',
          :Type => 'String',
          :Description => 'Whether or not to deploy the application as read only.',
          :Default => 'false',
          :AllowedValues => [ 'true', 'false' ],
          :ConstraintDescription => 'Must be either true or false'

parameter 'DeployBranch',
          :Default => 'master',
          :Description => 'The branch of the Media app to be deployed',
          :Type => 'String'

parameter 'Environment',
          :Default => 'development',
          :Description => 'The environment where the nodes should register',
          :Type => 'String',
          :AllowedValues => [ 'devops', 'development', 'qa', 'staging', 'production' ],
          :ConstraintDescription => 'Must be a valid Chef Environment.'

parameter 'AutoScalingMaxSize',
          :Type => 'Number',
          :Description => 'Maximum number of nodes in the tier',
          :Default => '6'

parameter 'DesiredCapacity',
          :Default => '1',
          :Description => 'The initial number of instances',
          :Type => 'Number',
          :MinValue => '1',
          :MaxValue => '6',
          :ConstraintDescription => 'Must be between 1 and 6 EC2 instances.'

parameter 'InstanceType',
          :Description => 'WebServer EC2 instance type',
          :Type => 'String',
          :Default => 't2.small',
          :ConstraintDescription => 'Must be a valid EC2 instance type.'

parameter 'ChefAttributes',
          Type: 'String',
          Description: 'Configuration file to pass to Chef.  Example: development/media/develop-media-dev.shopatron.com.json',
          Default: 'development/media/develop-media-dev.shopatron.com.json',
          AllowedValues: ['devops/media/develop-media-dev.shopatron.com.json',
                          'development/media/develop-media-dev.shopatron.com.json',
                          'qa/media/current-media-qa.shopatron.com.json',
                          'staging/media/media-stg.shopatron.com.json',
                          'mediaion/media/.shopatron.com.json'
                ]

if defined?(environment)
  if defined?(region)
    case region
      when 'us-west-2'
        case environment
          when 'production'
            @parameters['DesiredCapacity']['Default'] = '3'
            @parameters['InstanceType']['Default']    = 'm3.medium'
            @parameters['ChefAttributes']['Default']  = 'production//media.shopatron.com.json'
            @parameters['ChefAttributes']['AllowedValues'] = [
              'mediaion/media/media.shopatron.com.json'
            ]
          when 'staging', 'preview'
            @parameters['DesiredCapacity']['Default'] = '2'
            @parameters['InstanceType']['Default']    = 'm3.medium'
            @parameters['ChefAttributes']['Default']  = 'staging/media/media-stg.shopatron.com.json'
            @parameters['ChefAttributes']['AllowedValues'] = [
              'staging/media/media-stg.shopatron.com.json'
            ]
          when 'qa'
            @parameters['DesiredCapacity']['Default'] = '1'
            @parameters['InstanceType']['Default']    = 't2.medium'
            @parameters['ChefAttributes']['Default']  = 'qa/media/current-media-qa.shopatron.com.json'
            @parameters['ChefAttributes']['AllowedValues'] = [
              'qa/media/current-media-qa.shopatron.com.json'
            ]
          when 'development'
            @parameters['DesiredCapacity']['Default'] = '1'
            @parameters['InstanceType']['Default']    = 't2.small'
            if branch.nil?
              @parameters['ChefAttributes']['Default']  = 'development/media/develop-media-dev.shopatron.com.json'
            else
              @parameters['ChefAttributes']['Default']  = "development/media/#{branch}-media-dev.shopatron.com.json"
            end
            @parameters['ChefAttributes']['AllowedValues'] = [
              'development/media/develop-media-dev.shopatron.com.json',
              'development/media/current-media-dev.shopatron.com.json',
              'devops/media/develop-media-dvp.shopatron.com.json',
            ]
        end
      when 'us-east-1'
        case environment
          when 'mediaion'
            @parameters['DesiredCapacity']['Default'] = '3'
            @parameters['InstanceType']['Default']    = 'm3.medium'
            @parameters['ChefAttributes']['Default']  = 'mediaion/media/media.shopatron.com.json'
            @parameters['ChefAttributes']['AllowedValues'] = [
              'mediaion/media/media.shopatron.com.json'
            ]
        end
    end
  end
end
