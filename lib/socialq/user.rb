module SocialQ  
  class User
    
    class Topsy
      include HTTParty
    
      base_uri 'http://otter.topsy.com'
      default_params :output => 'json'
      format :json
    
      def self.author_info(twitter_id)
        response = get("/authorinfo.json?url=http://twitter.com/#{twitter_id}")
        response['response']
      end
    end
    
    class Twitter
      include HTTParty
    
      base_uri 'http://api.twitter.com'
      default_params :output => 'json'
      
      def initialize(uname, passwd)
        @auth = { :username => uname, :password => passwd }
      end
      
      def get_user(user)
        result = self.class.get("/1/users/lookup.json?screen_name=#{user}", :basic_auth => @auth)
        result[0] if result[0]
      end
    end
    
    include AASM
    
    aasm_state         :start
    aasm_state         :on_with_agent
    aasm_initial_state :start

    aasm_event :send_call do
      transitions :to => :on_with_agent, :from => :start
      @time = Time.now
    end
    
    attr_reader :guid,
                :phone_number, 
                :channel, 
                :time, 
                :agent, 
                :twitter_user, 
                :twitter_keywords, 
                :tweet_count, 
                :twitter_profile,
                :klout, 
                :social_influence_rank,
                :tweet_watchword,
                :queue_weight
    
    ##
    # Creates a User object
    #
    # @param [required, Hash] options a hash containing the options to generate a new Agent object
    # @param options [require, String] name the name of the agent
    # @param options [require, String] twitter_id the user's Twitter ID
    # @param options [require, String] phone_number the phone number to dial to reach the agent, must include '+' country code (ie - +14155551212)
    # @return [Object] an User object
    def initialize(options = {})
      raise ArgumentError, 'A hash with the :twitter_user set is required.' if options[:twitter_user] == nil
      raise ArgumentError, 'A hash with the :phone_number set is required.' if options[:phone_number] == nil
      raise ArgumentError, 'A hash with the :channel set is required.'      if options[:channel] == nil
      
      @guid                  = UUIDTools::UUID.random_create.to_s
      @twitter_user          = options[:twitter_user]
      @phone_number          = options[:phone_number]
      @channel               = options[:channel]
      @time                  = Time.now
      @agent                 = nil
      @tweet_watchword       = nil
      @tweet_count           = 0
      @klout_key             = options[:klout_key]
      @social_influence_rank, @klout = get_social_influence
      
      # Calcuate the initial queue weight for this contact
      @weight_rules = options[:weight_rules]
      calc_initial_weight
      
      @twitter_username   = options[:twitter_username]
      @twitter_password   = options[:twitter_password]
      @twitter_keywords   = options[:twitter_keywords]
      
      # Handle Twitter details
      twitter = Twitter.new(@twitter_username, @twitter_password)
      @twitter_profile = twitter.get_user(options[:twitter_user])
      launch_twitter_listener
    end
    
    ##
    # Sets the agent handling this user on a phone call
    #
    # @param [require, Object] agent the agent object
    # @return nil
    def set_agent(agent)
      @agent = agent
    end
    
    ##
    # Kills the Twitter thread that is following that user to watch Tweets for watchwords
    #
    # @return nil
    def kill_twitter_thread
      @twitter_thread.kill!
    end
    
    private
    
    ##
    #
    def get_social_influence
      author_info = Topsy::author_info @twitter_user      
      klout_info = JSON.parse(RestClient.get("http://api.klout.com/1/users/show.json?key=#{@klout_key}&users=#{@twitter_user}").body)
      if klout_info["status"] == 200
        return author_info['influence_level'], klout_info["users"][0]
      else
        return author_info['influence_level'], { :result => 'Not found' }
      end
    end
    
    ##
    #
    def calc_initial_weight
      @queue_weight = 0
      @queue_weight = @klout['score']['kscore'] * @weight_rules['influence'] if @klout['score']
      @queue_weight += @weight_rules['tweet'] if @channel == 'twitter'
      @queue_weight += @weight_rules['phone'] if @channel == 'phone'
    end
    
    ##
    #
    # @return nil
    def launch_twitter_listener
      @twitter_thread = Thread.new do
        client = TweetStream::Client.new(@twitter_username, @twitter_password)
        client.follow(@twitter_profile['id']) do |tweet|
          # If we get a matching word on our watchlist lets set the user watchword triggered
          @twitter_keywords.each { |word| twitter_alert!(word) if tweet[:text].match(word) }
        end
      end
    end
    
    ##
    #
    # @return nil
    def twitter_alert!(watchword)
      @tweet_watchword = watchword
      @tweet_count += 1
    end
    
  end
end