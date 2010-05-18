module SocialQ
  class Rabbit
    require 'bunny'
    
    attr_reader :agentq, :callq
    
    ##
    # Sets up the connections to the appropriate queues using Bunny to RabbitMQ
    #
    # @return nil
    def initialize(params)
      bunny_logfile = File.expand_path(File.dirname(__FILE__) + '../../../' + params['log_file'])
      bunny = Bunny.new(:user    => params['user'],
                        :pass    => params['pass'],
                        :host    => params['host'],
                        :port    => params['port'],
                        :vhost   => params['vhost'],
                        :logging => params['logging'],
                        :logfile => bunny_logfile)
      bunny.start
      
      @socialq = bunny.queue(params['socialq'])
      @dumpq = bunny.queue(params['dumpq']) if params['dumpq']
      
      @agentq = bunny.queue(params['agentq'])
      @callq = bunny.queue(params['callq'])
      @responseq = bunny.queue(params['callq'])
    end

    ##
    # Publishes a JSON document to the message queues
    #
    # @params [String] a JSON document to publish to the messages queues
    # @return nil
    def publish_socialq(msg)
      @socialq.publish(msg)
      @dumpq.publish(msg) if @dumpq
    end
    
    ##
    # Reads the social queue and returns the JSON document
    #
    # @return [String] the last message from the message queue
    def read_socialq
      @socialq.pop[:payload]
    end
  end
end