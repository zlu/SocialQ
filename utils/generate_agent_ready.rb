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

json = '{"customer_guid": "c13b9a75-3b46-45f2-96be-61391f9a10c4", "agent_phone": "19168538550"}'
p json
q = bunny.queue('agentq')
q.publish(json)
p 'Published some data!'