$: << File.expand_path(File.dirname(__FILE__))
%w(rubygems json lib/socialq tropo-webapi-ruby).each { |lib| require lib }

# Load configuration
APP_CONFIG = YAML.load(File.open('config/application.yml'))
# Start the logger
@log = Logger.new(STDOUT)
@log.level = Logger::DEBUG
@log.info 'Starting SocialQ'

@socialq = SocialQ::SessionQueue.new(APP_CONFIG['rabbit_mq'])

bunny = Bunny.new(:user    => APP_CONFIG['rabbit_mq']['user'],
                  :pass    => APP_CONFIG['rabbit_mq']['pass'],
                  :host    => APP_CONFIG['rabbit_mq']['host'],
                  :port    => APP_CONFIG['rabbit_mq']['port'],
                  :vhost   => APP_CONFIG['rabbit_mq']['vhost'],
                  :logging => APP_CONFIG['rabbit_mq']['logging'])
bunny.start
agentq = bunny.queue(APP_CONFIG['rabbit_mq']['agentq'])
callq = bunny.queue(APP_CONFIG['rabbit_mq']['callq'])

threads = []
# threads << Thread.new do
#   agentq.subscribe { |msg| @log.debug JSON.parse(msg[:payload]) }
# end

threads << Thread.new do
  callq.subscribe do |msg|
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
      p '*'*10
      p twitter_user
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
                                            :queue_name       => tropo_event['queue_name'] })
    end
  end
end

threads.each { |thread| thread.join }
