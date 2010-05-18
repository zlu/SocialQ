$: << File.expand_path(File.dirname(__FILE__))
%w(rubygems json lib/socialq tropo-webapi-ruby restclient).each { |lib| require lib }

# Load configuration
APP_CONFIG = YAML.load(File.open(File.expand_path(File.dirname(__FILE__) + '/config/application.yml')))
# Start the logger
@log = Logger.new(File.expand_path(File.dirname(__FILE__) + '/' + APP_CONFIG['logging']['file']))
@log.level = Logger::DEBUG
@log.info 'Starting SocialQ'

@socialq = SocialQ::SessionQueue.new(APP_CONFIG['rabbit_mq'])

##
# Connects to the RabbitMQ instance specified
#
# @params [String] the name of the queue to connect to
# @return [Object] a handle to the queue specified
def connect_bunny(queue)
  bunny_logfile = File.expand_path(File.dirname(__FILE__) + '/' + APP_CONFIG['rabbit_mq']['log_file'])
  bunny = Bunny.new(:user    => APP_CONFIG['rabbit_mq']['user'],
                    :pass    => APP_CONFIG['rabbit_mq']['pass'],
                    :host    => APP_CONFIG['rabbit_mq']['host'],
                    :port    => APP_CONFIG['rabbit_mq']['port'],
                    :vhost   => APP_CONFIG['rabbit_mq']['vhost'],
                    :logging => APP_CONFIG['rabbit_mq']['logging'],
                    :logfile => bunny_logfile)
  bunny.start
  bunny.queue(APP_CONFIG['rabbit_mq'][queue])
end

threads = []

# Thread that watches for agents and their actions
threads << Thread.new do
  agentq = connect_bunny('agentq')
  agentq.subscribe do |msg|
    # We are expecting a JSON document like this:
    # {
    #     "customer_guid": "5f43ae91-0ee3-4e42-b23a-7c3f636fc355",
    #     "agent_phone": "+14155551212",
    #     "action": "phone" # (or tweet)
    # }
    session = nil
    message = JSON.parse msg[:payload]
    @log.info 'AgentQ message received!: ' + message.inspect
    @log.info '*'*10
    
    # Now we need to find the corresponding User in our User array matching on GUID
    @socialq.users.each do |user|
      if user.guid == message['customer_guid']
        session = user
        break
      end
    end
    
    # Only call them if that is what the agent wants, as they may have responded with a tweet and that is good enough
    if message['action'] == 'phone'
      if session && session.channel == 'phone'
        
        # Customer is already in the conference, so lets just connect the agent
        url = APP_CONFIG['tropo']['url'] + "&request_type=session_api&queue_name=#{session.queue_name}&phone_number=#{message['agent_phone']}"
        RestClient.get url
      elsif session && session.channel == 'twitter'
        
        # Since this originated as a Tweet, we need to connect both the user and the agent in the same Q
        queue_name = Time.now.to_i.to_s
        
        # First the agent
        Thread.new do
          url = APP_CONFIG['tropo']['url'] + "&request_type=session_api&queue_name=#{queue_name}&phone_number=#{message['agent_phone']}"
          RestClient.get url
        end
        
        # Then the customer
        url = APP_CONFIG['tropo']['url'] + "&request_type=session_api&queue_name=#{queue_name}&phone_number=#{session.phone_number}"
        RestClient.get url
      end
    end
    
    # Delete the user from queue
    @socialq.delete_user(session.guid)
  end
end

# Thread that watches for new calls coming in
threads << Thread.new do
  callq = connect_bunny('callq')
  callq.subscribe do |msg|
    tropo_event = JSON.parse msg[:payload]
    @log.info 'SocialQ message received!: ' + tropo_event.inspect
    @log.info '*'*10
    
    if tropo_event['session']['from']['channel'] == 'VOICE'
      
      # Need to find the corresponding Twitter ID based on CallerID
      twitter_user = nil
      APP_CONFIG['users'].each do |user|
        if tropo_event['session']['from']['id'] == user['phone_number']
          twitter_user = user['twitter_user']
          break
        end
      end
      
      # Create the user
      @socialq.add_user SocialQ::User.new({ :twitter_user     => twitter_user,
                                            :phone_number     => tropo_event['session']['from']['id'],
                                            :channel          => 'phone',
                                            :twitter_username => APP_CONFIG['twitter']['username'],
                                            :twitter_password => APP_CONFIG['twitter']['password'],
                                            :klout_key        => APP_CONFIG['twitter']['klout_key'],
                                            :twitter_keywords => APP_CONFIG['twitter']['keywords'],
                                            :weight_rules     => APP_CONFIG['weight_rules'],
                                            :queue_name       => tropo_event['queue_name'] })
    else
      
      # Need to find the corresponding Phone # based on Twitter ID
      phone_number = nil
      APP_CONFIG['users'].each do |user|
        if tropo_event['session']['from']['id'] == user['twitter_user']
          phone_number = user['phone_number']
          break
        end
      end
      
      # Create the user
      @socialq.add_user SocialQ::User.new({ :twitter_user     => tropo_event['session']['from']['id'],
                                            :phone_number     => phone_number,
                                            :channel          => 'twitter',
                                            :twitter_username => APP_CONFIG['twitter']['username'],
                                            :twitter_password => APP_CONFIG['twitter']['password'],
                                            :klout_key        => APP_CONFIG['twitter']['klout_key'],
                                            :twitter_keywords => APP_CONFIG['twitter']['keywords'],
                                            :weight_rules     => APP_CONFIG['weight_rules'],
                                            :queue_name       => 'twitter' })
    end
  end
end

# Thread that watches for resets
threads << Thread.new do
  resetq = connect_bunny('resetq')
  resetq.subscribe do |msg|
    @log.info '+'*10
    @log.info msg[:payload]
    @log.info '+'*10
  end
end

threads.each { |thread| thread.join }
