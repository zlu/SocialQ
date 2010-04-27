%w(rubygems bunny json).each { |lib| require lib }
config = YAML.load(File.open('../config/application.yml'))
bunny = Bunny.new(:user    => config['rabbit_mq']['user'],
                  :pass    => config['rabbit_mq']['pass'],
                  :host    => config['rabbit_mq']['host'],
                  :port    => config['rabbit_mq']['port'],
                  :vhost   => config['rabbit_mq']['vhost'],
                  :logging => config['rabbit_mq']['logging'])

p bunny
p '*'*10
bunny.start

social_q = bunny.queue(config['rabbit_mq']['socialq'])

10.times do
  social_q.publish({ :foo => 'bar' }.to_json)
end

# messages = []
# msg = nil
# while msg != :queue_empty
#   msg = social_q.pop[:payload]
#   messages << msg if msg != :queue_empty
# end
# p messages

bunny.stop
