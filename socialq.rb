$: << File.expand_path(File.dirname(__FILE__))
%w(rubygems json lib/socialq tropo-webapi-ruby restclient).each { |lib| require lib }

# Load configuration
APP_CONFIG = YAML.load(File.open('config/application.yml'))
# Start the logger
@log = Logger.new(STDOUT)
@log.level = Logger::DEBUG
@log.info 'Starting SocialQ'

@socialq = SocialQ::SessionQueue.new(APP_CONFIG['rabbit_mq'])

bunny_agentq = Bunny.new(:user    => APP_CONFIG['rabbit_mq']['user'],
                         :pass    => APP_CONFIG['rabbit_mq']['pass'],
                         :host    => APP_CONFIG['rabbit_mq']['host'],
                         :port    => APP_CONFIG['rabbit_mq']['port'],
                         :vhost   => APP_CONFIG['rabbit_mq']['vhost'],
                         :logging => APP_CONFIG['rabbit_mq']['logging'])

bunny_callq = Bunny.new(:user    => APP_CONFIG['rabbit_mq']['user'],
                        :pass    => APP_CONFIG['rabbit_mq']['pass'],
                        :host    => APP_CONFIG['rabbit_mq']['host'],
                        :port    => APP_CONFIG['rabbit_mq']['port'],
                        :vhost   => APP_CONFIG['rabbit_mq']['vhost'],
                        :logging => APP_CONFIG['rabbit_mq']['logging'])
bunny_agentq.start
bunny_callq.start

agentq = bunny_agentq.queue(APP_CONFIG['rabbit_mq']['agentq'])
callq = bunny_callq.queue(APP_CONFIG['rabbit_mq']['callq'])

threads = []
threads << Thread.new do
  agentq.subscribe do |msg|
    p 'AgentQ message received!'
    # We are expecting a JSON document like this:
    # {
    #     "customer_guid": "5f43ae91-0ee3-4e42-b23a-7c3f636fc355",
    #     "agent_phone": "+14155551212"
    # }
    session = nil
    message = JSON.parse msg[:payload]
    @socialq.users.each do |user|
      p user.guid
      p '*'*10
      session = user if user.guid == message['customer_guid']
      break
    end
    if session && session.channel == 'phone'
      url = APP_CONFIG['tropo']['url'] + "&request_type=session_api&queue_name=#{session.queue_name}&phone_number=#{message['agent_phone']}"
      RestClient.get url
    else
      p 'foobar'
    end
  end
end

threads << Thread.new do
  callq.subscribe do |msg|
    p 'CallQ message received!'
    tropo_event = JSON.parse msg[:payload]
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

threads.each { |thread| thread.join }
