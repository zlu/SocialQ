module SocialQ
  require 'aasm'
  class Agent
    include AASM
    aasm_state         :unavailable
    aasm_state         :available
    aasm_initial_state :unavailable

    aasm_event :send_call do
      transitions :to => :unavailable, :from => :available
      @time = Time.now
    end
    
    aasm_event :make_available do
      transitions :to => :available, :from => :unavailable
      @time = Time.now
    end
    
    aasm_event :make_unavailable do
      transitions :to => :unavailable, :from => :available
      @time = Time.now
    end
    
    attr_reader :guid, :name, :phone_number, :time, :user
    
    ##
    # Creates an Agent object
    #
    # @param [required, Hash] options a hash containing the options to generate a new Agent object
    # @param options [require, String] name the name of the agent
    # @param options [require, String] phone_no the phone number to dial to reach the agent, must include '+' country code (ie - +14155551212)
    # @return [Object] an Agent object
    def initialize(options = {})
      raise ArgumentError, 'A hash with the :name set is required.'         if options[:name] == nil
      raise ArgumentError, 'A hash with the :phone_number set is required.' if options[:phone_number] == nil
      
      @guid         = UUIDTools::UUID.random_create.to_s
      @name         = options[:name]
      @phone_number = options[:phone_number]
      @time         = Time.now
      @user         = nil
    end
  
    def set_user(user)
      @user = user
    end
  end
end