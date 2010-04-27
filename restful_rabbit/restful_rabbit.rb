%w(rubygems sinatra bunny).each { |lib| require lib }

@bunny = Bunny.new(:user => 'rabbit0002',
                   :pass => 'RbIEJfCuMc',
                   :host => 'ec2-67-202-42-147.compute-1.amazonaws.com',
                   :port => '15002',
                   :logging => true)
@bunny.start
@social_q = @bunny.queue('social_q')
@agent_q  = @bunny.queue('agent_q')

get '/messages' do
  messages = Array.new
  msg = nil
  while msg != :queue_empty
    msg = @social_q.pop[:payload]
    messages << msg if msg != :queue_empty
  end
  messages
end

post '/agent_ready' do
  @agent_q.publish(request.env["rack.input"].read)
end