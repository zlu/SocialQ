$: << File.expand_path(File.dirname(__FILE__))
%w(rubygems logger).each { |lib| require lib }

# Load the configuration
APP_CONFIG = YAML.load(File.open('config/application.yml'))
# Start the logger
@log = Logger.new(STDOUT)
@log.level = Logger::DEBUG
@log.info 'Starting Project Squirrel'

%w(right_aws sinatra thread tropo-webapi-ruby aasm lib/agent lib/user).each { |lib| require lib }
include Twitter
twitter_thread, twitter_queue = monitor_public_stream(APP_CONFIG['twitter']['username'], 
                                                      APP_CONFIG['twitter']['password'], 
                                                      APP_CONFIG['twitter']['keywords'])

## Start Amazon SQS
# @sqs = RightAws::Sqs.new(APP_CONFIG['amazon']['aws_access_key'], 
#                          APP_CONFIG['amazon']['aws_secret_access_key'])
# @call_queue = @sqs.queue(APP_CONFIG['amazon']['call_queue'])
# @agent_queue = @sqs.queue(APP_CONFIG['amazon']['agent_queue'])
## Stop Amazon SQS

## Start Sinatra section
# set :sessions, true
# set :port, APP_CONFIG['sinatra']['port']
# 
# post '/start.json' do
#   tropo_event = Tropo::Generator.parse request.env["rack.input"].read
#   p tropo_event
# end
# 
# post '/queue.json' do
# end
## Stop Sinatra section

