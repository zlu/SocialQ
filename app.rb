$: << File.expand_path(File.dirname(__FILE__))
%w(rubygems logger restclient haml uri mongo).each { |lib| require lib }

# Load the configuration
APP_CONFIG = YAML.load(File.open('config/application.yml'))

p APP_CONFIG['mongo']['collection']

# Start the logger
@@log = Logger.new(STDOUT)
@@log.level = Logger::DEBUG
@@log.info 'Starting SocialQ Sinatra App'

%w(sinatra tropo-webapi-ruby bunny json).each { |lib| require lib }

set :sessions, true
set :port, APP_CONFIG['sinatra']['port']
set :views, File.dirname(__FILE__) + '/templates'
set :haml, { :format => :html5 }

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

# Setup Mongo connection
def connect_to_mongo
  uri = URI.parse(ENV['MONGOHQ_URL'])
  conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
  # uri = URI.parse(APP_CONFIG['mongo']['url'])
  # conn = Mongo::Connection.from_uri(APP_CONFIG['mongo']['url'])
  conn.db(uri.path.gsub(/^\//, ''))
end

# Fetch the scenarios from the MongoDB instance
def fetch_scenarios
  db = connect_to_mongo
  collection = db.collection(APP_CONFIG['mongo']['collection'])  
  scenarios = {}
  collection.find.each { |doc| scenarios.merge!(doc) }
  scenarios.each_with_index do | scenario, index |
    scenarios[index].delete('_id')
  end
  @@log.info scenarios.inspect
  scenarios
end

def get_dump
  socialq = connect_to_rabbit('socialq')
  
  messages = Array.new
  msg = nil
  while msg != :queue_empty
    msg = socialq.pop[:payload]
    if msg != :queue_empty
      messages << JSON.parse(msg)
    end
  end
  messages
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
        on :event => 'hangup', :next => '/hangup.json'
        say "Merci de votre appel, s'il vous plaît patienter pendant que nous trouver un agent pour vous.", :voice => 'florence'
        conference :id        => time, 
                   :name      => 'SocialQ', 
                   :sendTones => false, 
                   :beep      => false, 
                   :choices   => 'foo, bar'
      end
      queue_message = tropo_event.merge!({ :queue_name => time })
      callq.publish(queue_message.to_json)
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

get '/dump' do
  get_dump.to_json
end

post '/publish_message' do
  socialq = connect_to_rabbit('socialq')
  socialq.publish(request.env["rack.input"].read)
end

post '/agent_ready' do
  agentq = connect_to_rabbit('agentq')
  agentq.publish(request.env["rack.input"].read)
end

get '/reset' do
  resetq = connect_to_rabbit('resetq')
  resetq.publish({ :action => 'reset' }.to_json)
  haml :reset
end

get '/scenarios' do
  @scenarios = fetch_scenarios
  haml :scenarios
end

get '/scenario/:scenario' do |scenario|
  @scenario, session['scenario'] = scenario, scenario
  scenarios = fetch_scenarios
  @possible_scenarios = ''
  scenarios.each { |k, v| 
    @possible_scenarios += k + ' '
  }
  @messages = scenarios[scenario]
  
  if @messages
    haml :scenario
  else
    haml :unkown
  end
end

get '/posts/:message_number' do |message_number|
  socialq = connect_to_rabbit('dumpq')
  scenarios = fetch_scenarios
  socialq.publish(scenarios[session['scenario']][message_number.to_i].to_json)
  redirect "/scenario/#{session['scenario']}"
end

# Used to fetch messages from the dump q and add them as a scenario when given a name
get '/load_scenario/:scenario' do |scenario|
  @scenario = scenario
  messages = get_dump
  
  db = connect_to_mongo
  collection = db.collection('socialq_scenarios')
  collection.insert({ @scenario.to_sym => messages })
  @results = []
  collection.find.each { |doc| @results << doc }
  haml :scenario_loaded
end

get '/collection/:collection' do |collection|
  db = connect_to_mongo
  collection = db.collection('socialq_scenarios')
  @results = []
  collection.find.each { |doc| @results << doc }
  @results.inspect
end

get '/mongo_url' do
  ENV['MONGOHQ_URL']
end