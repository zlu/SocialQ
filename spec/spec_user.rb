$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SocialQ::User::Topsy do
  it "should return a Ruby hash of author info" do
    SocialQ::User::Topsy::author_info('barackobama')['name'].should == 'Barack Obama'
  end
end

describe SocialQ::User::Twitter do
  it "should fetch user details from twitter" do
    config = YAML.load(File.open('config/application.yml'))
    twitter = SocialQ::User::Twitter.new(config['twitter']['username'], config['twitter']['password'])
    user = twitter.get_user('barackobama')
    user['name'].should == 'Barack Obama'
  end
end

describe SocialQ::User do
  before(:all) do
    @config = YAML.load(File.open('config/application.yml'))
    @user = SocialQ::User.new({ :twitter_user     => 'barackobama', 
                                :phone_number     => '+14155551212',
                                :channel          => 'twitter',
                                :twitter_username => @config['twitter']['username'],
                                :twitter_password => @config['twitter']['password'],
                                :klout_key        => @config['twitter']['klout_key'],
                                :twitter_keywords => @config['twitter']['keywords'],
                                :weight_rules     => @config['weight_rules'],
                                :queue_name       => '1234' })
  end
  
  it "should raise argument errors if a new user object is created without an option set" do
   begin
      result = SocialQ::User.new({ :name => 'John Doe' })
    rescue => e
      e.to_s.should == 'A hash with the :twitter_user set is required.'
    end
    
    begin
      result = SocialQ::User.new({ :name => 'John Doe', :twitter_user => 'johndoe' })
    rescue => e
      e.to_s.should == 'A hash with the :phone_number set is required.'
    end
    
    begin
      result = SocialQ::User.new({ :name => 'John Doe', :twitter_user => 'johndoe', :phone_number => '+14155551212' })
    rescue => e
      e.to_s.should == 'A hash with the :channel set is required.'
    end
  end
  
  it "should populate the twitter_profile method" do
    @user.twitter_profile['name'].should == 'Barack Obama'
  end

  it "should create a new user object with the appropriate values set" do
    @user.twitter_user.should == 'barackobama'
    @user.phone_number.should == '+14155551212'
  end
  
  it "should have a user object should successfully transition through all of its state" do
    @user.start?.should == true
    @user.send_call!
    @user.on_with_agent?.should == true
  end
  
  it "should set the agent to a new object" do
    @user.set_agent :foo => 'bar'
    @user.agent.should == { :foo => 'bar' }
  end
  
  it "should set the social_influence_rank" do
    @user.social_influence_rank.should == 10
  end
  
  it "should set the klout" do
    @user.klout['twitter_screen_name'].should == 'BarackObama'
  end
  
  it "should have a guid instance method" do
    @user.guid.should_not == nil
  end
  
  it "should have a weight of" do
    @user.queue_weight.should == 208
  end
  
  it "should set the Twitter watch_word when a matching tweet is received" do
     # First, create a user object so we start monitoring the stream of the user
     user = SocialQ::User.new({ :twitter_user     => 'squirrelrific', 
                                :phone_number     => '+14155551212',
                                :channel          => 'twitter',
                                :twitter_username => @config['twitter']['username'],
                                :twitter_password => @config['twitter']['password'],
                                :klout_key        => @config['twitter']['klout_key'],
                                :twitter_keywords => @config['twitter']['keywords'],
                                :weight_rules     => @config['weight_rules'],
                                :queue_name       => '1234' })
    # Now, launch a tweet as that user
    httpauth = Twitter::HTTPAuth.new(@config['twitter']['username'], @config['twitter']['password'])
    client = Twitter::Base.new(httpauth)
    client.update("#{UUIDTools::UUID.random_create} Squirrels fail!")
    
    sleep 5
    user.tweet_watchword.should == 'fail'
  end
end