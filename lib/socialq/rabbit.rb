module SocialQ
  class Rabbit
    require 'bunny'
    
    attr_reader :agentq, :callq
    
    def initialize(params)
      bunny = Bunny.new(:user    => params['user'],
                        :pass    => params['pass'],
                        :host    => params['host'],
                        :port    => params['port'],
                        :vhost   => params['vhost'],
                        :logging => params['logging'])
      bunny.start
      
      @socialq = bunny.queue(params['socialq'])
      @dumpq = bunny.queue(params['dumpq']) if params['dumpq']
      
      @agentq = bunny.queue(params['agentq'])
      @callq = bunny.queue(params['callq'])
      @responseq = bunny.queue(params['callq'])
    end
  
    def publish_socialq(msg)
      @socialq.publish(msg)
      @dumpq.publish(msg) if @dumpq
    end
    
    def read_socialq
      @socialq.pop[:payload]
    end
  end
end