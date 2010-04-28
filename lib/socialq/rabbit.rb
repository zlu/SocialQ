%w(bunny json).each { |lib| require lib }

module SocialQ
  class Rabbit

    attr_reader :agentq
    
    def initialize(params)
      bunny = Bunny.new(:user    => params['user'],
                        :pass    => params['pass'],
                        :host    => params['host'],
                        :port    => params['port'],
                        :vhost   => params['vhost'],
                        :logging => params['logging'])
      bunny.start
      
      @socialq = bunny.queue(params['socialq'])
      @agentq = bunny.queue(params['agentq'])
    end
  
    def publish_socialq(msg)
      @socialq.publish(msg.to_json)
    end
    
    def read_socialq
      @socialq.pop[:payload]
    end
  end
end