module SocialContactCenter
  class ContactQueue
    require 'json'
    
    attr_reader :users, :agents
    
    ##
    # Create a new ContactQueue Object
    #
    # @param [required, Integer] timer in seconds to scan the available agents
    # @return [Object] ContactQueue
    def initialize(timer)
      @users  = []
      @agents = []
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
      { :users => @users, :agents => @agents }.to_json
    end
    
    private
    
    ##
    # Launches a thread to scan available agents every X seconds
    #
    # @param [required, Integer] timer in seconds to scan the available agents
    # @return nil
    def launch_agent_scanner(timer)
      @scanning_thread = Thread.new do
        if @users.length > 0
          p 'Scanning for available agents'
        end
        sleep timer
      end
    end
  end
end