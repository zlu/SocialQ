# VERSION 2
%w(rubygems bunny json).each { |lib| require lib }
config = YAML.load(File.open('../config/application.yml'))
bunny = Bunny.new(:user    => 'rabbit0002',
                  :pass    => 'RbIEJfCuMc',
                  :host    => 'ec2-67-202-42-147.compute-1.amazonaws.com',
                  :port    => 15002,
                  :vhost   => '/rabbit0002',
                  :logging => true)
bunny.start

json = '{"customer_guid": "818bc7c6-c223-4446-a420-bf1246ea20b6", "agent_phone": "14153675082"}'
p json
q = bunny.queue('agentq')
q.publish(json)
p 'Published some data!'