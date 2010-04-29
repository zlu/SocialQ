module SocialQ
  class SessionQueue
    require 'json'
    
    attr_reader :users, :agents
    
    ##
    # Create a new ContactQueue Object
    #
    # @param [required, Integer] timer in seconds to scan the available agents
    # @param [required, Hash] amazon_options
    # @return [Object] ContactQueue
    def initialize(queue_config)
      @users  = []
      @agents = []
      
      @bunny = Rabbit.new(queue_config)
      # Launch the timer to search for agents
      launch_agent_scanner
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
                        :klout                 => user.klout,
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
    
    private
    
    ##
    # Launches a thread to scan available agents every X seconds
    #
    # @param [required, Integer] timer in seconds to scan the available agents
    # @return nil
    def launch_agent_scanner
      @scanning_thread = Thread.new do
        @bunny.agentq.subscribe { |msg| p msg }
      end
    end
  end
end