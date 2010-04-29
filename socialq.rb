$: << File.expand_path(File.dirname(__FILE__))
%w(rubygems json lib/socialq).each { |lib| require lib }

# Load configuration
APP_CONFIG = YAML.load(File.open('config/application.yml'))
# Start the logger
@log = Logger.new(STDOUT)
@log.level = Logger::DEBUG
@log.info 'Starting SocialQ'

socialq = SocialQ::SessionQueue.new(APP_CONFIG['rabbit_mq'])

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
threads << Thread.new do
  agentq.subscribe { |msg| @log.debug JSON.parse(msg[:payload]) }
end


threads << Thread.new do
  callq.subscribe { |msg| @log.debug JSON.parse(msg[:payload]) }
end

threads.each { |thread| thread.join }
