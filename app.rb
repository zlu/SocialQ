$: << File.expand_path(File.dirname(__FILE__))
%w(rubygems logger).each { |lib| require lib }

# Load the configuration
APP_CONFIG = YAML.load(File.open('config/application.yml'))

# Start the logger
@log = Logger.new(STDOUT)
@log.level = Logger::DEBUG
@log.info 'Starting SocialQ'

%w(sinatra tropo-webapi-ruby bunny json).each { |lib| require lib }

set :sessions, true
set :port, APP_CONFIG['sinatra']['port']

def connect_to_rabbit(queue)
  bunny = Bunny.new(:user    => APP_CONFIG['rabbit_mq']['user'],
                    :pass    => APP_CONFIG['rabbit_mq']['pass'],
                    :host    => APP_CONFIG['rabbit_mq']['host'],
                    :port    => APP_CONFIG['rabbit_mq']['port'],
                    :vhost   => APP_CONFIG['rabbit_mq']['vhost'],
                    :logging => APP_CONFIG['rabbit_mq']['logging'])
  bunny.start
  bunny.queue(APP_CONFIG['rabbit_mq'][queue])
end

# Section or dealng wth Tropo WebAPI

post '/start.json' do
  tropo_event = Tropo::Generator.parse request.env["rack.input"].read
  if tropo_event['session']['parameters']
    tropo = Tropo::Generator.new do
      on :event => 'error', :next => '/error.json'
      call({ :to              => 'tel:+' + tropo_event.session.parameters.phone_number, 
             :from            => '6172977928',
             :network         => 'PSTN',
             :channel         => 'VOICE',
             :timeout         => 30,
             :answer_on_media => false })
      say "Nous sommes sur le point de vous connecter, s'il vous plaît attendre.", :voice => 'florence'
      conference :id => tropo_event.session.parameters.queue_name, :name => 'SocialQ', :beep => false
    end
    tropo.response
  else
    callq = connect_to_rabbit('callq')
  
    if tropo_event.session.from.channel == 'VOICE'
      time = Time.now.to_i.to_s
      tropo = Tropo::Generator.new do
        on :event => 'leave', :next => '/hangup.json'
        say "Merci de votre appel, s'il vous plaît patienter pendant que nous trouver un agent pour vous.", :voice => 'florence'
        conference :id        => time, 
                   :name      => 'SocialQ', 
                   :sendTones => false, 
                   :beep      => false, 
                   :choices   => 'foo, bar' do
          on :event => 'leave', :next => '/hangup.json'
        end
        #on :event => 'continue', :next => '/conferenced.json'
      end
      queue_message = tropo_event.merge!({ :queue_name => time })
      callq.publish(queue_message.to_json)
      p tropo.response
      tropo.response
    else
      callq.publish(tropo_event.to_json)
    end
  end
end

post '/error.json' do
  p Tropo::Generator.parse request.env["rack.input"].read
end

post '/hangup.json' do
  p Tropo::Generator.parse request.env["rack.input"].read
end

# Section for dealing with RESTful Rabbit Interface
get '/messages' do
  socialq = connect_to_rabbit('socialq')
  
  messages = Array.new
  msg = nil
  while msg != :queue_empty
    msg = socialq.pop[:payload]
    if msg != :queue_empty
      messages << JSON.parse(msg)
    end
  end
  messages.to_json
end

get '/scenario' do
  dumpq = connect_to_rabbit('dumpq')
  
  messages = Array.new
  msg = nil
  while msg != :queue_empty
    msg = dumpq.pop[:payload]
    if msg != :queue_empty
      messages << JSON.parse(msg)
    end
  end
  messages.to_json
end

post '/publish_message' do
  socialq = connect_to_rabbit('socialq')
  socialq.publish(request.env["rack.input"].read)
end

post '/agent_ready' do
  agentq = connect_to_rabbit('agentq')
  agentq.publish(request.env["rack.input"].read)
end

post '/reset' do
  resetq = connect_to_rabbit('resetq')
  resetq.publish(request.env["rack.input"].read)
end

get '/test' do
  { :foo => 'bar' }.to_json
end