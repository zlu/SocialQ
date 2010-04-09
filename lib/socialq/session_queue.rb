module SocialQ
  class SessionQueue
    require 'json'
    
    attr_reader :users, :agents, :session_sqs, :agent_sqs
    
    ##
    # Create a new ContactQueue Object
    #
    # @param [required, Integer] timer in seconds to scan the available agents
    # @param [required, Hash] amazon_options
    # @return [Object] ContactQueue
    def initialize(timer, amazon_options)
      @users  = []
      @agents = []
      
      # Setup Amazon Services
      open_amazon_sqs(amazon_options)
      open_amazon_sdb(amazon_options)
      
      # Launch the timer to search for agents
      launch_agent_scanner(timer)
    end
    
    ##
    # Adds a user to the @users queue list
    #
    # @param [Object] user the user to add to the queue
    # @return nil
    def add_user(user)
      @users << user
    end
    
    ##
    # Deletes a user from the @users queue list
    #
    # @param [Object] user to deleted from the queue
    # @return nil
    def delete_user(user)
      @users.delete(user)
    end
    
    ##
    # Adds an agent to the @agents list
    #
    # @param [Object] agent to deleted from the queue
    # @return nil
    def add_agent(agent)
      @agents << agent
    end
    
    def render_json
      user_array = []
      @users.each do |user|
        user_array << { :guid                  => user.guid,
                        :name                  => user.name,
                        :social_influence_rank => user.social_influence_rank,
                        :channel               => user.channel,
                        :phone_number          => user.phone_number,
                        :queue_weight          => user.queue_weight,
                        :twitter_keywords      => user.twitter_keywords,
                        :twitter_profile       => user.twitter_profile,
                        :time                  => user.time }
      end
      
      agent_array = []
      @agents.each do |agent|
        agent_array << { :guid => agent.guid,
                         :name => agent.name,
                         :phone_number => agent.phone_number }
      end
      
      { :users => user_array, :agents => agent_array }.to_json
    end
    
    def open_amazon_sqs(amazon_options)
      # Setup the Amazon SQS connections
      client = AWS::SQS::Client.new(amazon_options[:aws_access_key], 
                                    amazon_options[:aws_secret_access_key], 
                                    :endpoint => amazon_options[:endpoint])
      @session_sqs = client.create_queue(amazon_options[:session_sqs])
      @agent_sqs = client.create_queue(amazon_options[:agent_sqs])
    end
    
    def open_amazon_sdb(amazon_options)
      # Setup the Amazon Simple DB connections to persist messages, to check for duplicates
      domain_exists = false
      @simple_db = RightAws::SdbInterface.new(amazon_options[:aws_access_key],
                                              amazon_options[:aws_secret_access_key], 
                                              { :multi_thread => false })
      domain_exists = false
      @simple_db.list_domains[:domains].each { |domain| domain_exists == true if domain == amazon_options[:db] }
      @simple_db.create_domain(amazon_options[:db]) unless domain_exists
    end
    
    private
    
    ##
    # Launches a thread to scan available agents every X seconds
    #
    # @param [required, Integer] timer in seconds to scan the available agents
    # @return nil
    def launch_agent_scanner(timer)
      @scanning_thread = Thread.new do
        p 'Scanning for available agents'
        agent_messages = @agent_sqs.receive_messages
        sleep timer
      end
    end
  end
end