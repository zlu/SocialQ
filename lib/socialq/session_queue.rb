module SocialQ
  class SessionQueue
    require 'thread'
    
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
      
      @semaphore = Mutex.new
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
    
    def publish_json
      user_array = []
      @users.each do |user|
        user_array << { :guid                  => user.guid,
                        :social_influence_rank => user.social_influence_rank,
                        :channel               => user.channel,
                        :phone_number          => user.phone_number,
                        :queue_weight          => user.queue_weight,
                        :twitter_profile       => user.twitter_profile,
                        :klout                 => user.klout,
                        :tweet_watchword       => user.tweet_watchword, # The last Tweet they did that triggered an increase in weight
                        :time                  => user.time }
      end
      
      agent_array = []
      @agents.each do |agent|
        agent_array << { :guid => agent.guid,
                         :name => agent.name,
                         :phone_number => agent.phone_number }
      end

      result = { :users => user_array, :agents => agent_array }.to_json
      @bunny.publish_socialq(result)
      result
    end
  end
end