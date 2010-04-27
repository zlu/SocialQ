%w(rubygems sinatra json bunny).each { |lib| require lib }

config = YAML.load(File.open('../config/application.yml'))
bunny = Bunny.new(:user    => config['rabbit_mq']['user'],
                  :pass    => config['rabbit_mq']['pass'],
                  :host    => config['rabbit_mq']['host'],
                  :port    => config['rabbit_mq']['port'],
                  :vhost   => config['rabbit_mq']['vhost'],
                  :logging => config['rabbit_mq']['logging'])
bunny.start
@@socialq = bunny.queue(config['rabbit_mq']['socialq'])
@@agentq  = bunny.queue(config['rabbit_mq']['agentq'])

get '/messages' do
  messages = Array.new
  msg = nil
  while msg != :queue_empty
    msg = @@socialq.pop[:payload]
    if msg != :queue_empty
      messages << JSON.parse(msg)
    end
  end
  messages.to_json
end

post '/agent_ready' do
  @@agentq.publish(request.env["rack.input"].read)
end