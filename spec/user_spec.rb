# billing_bridge_spec.rb
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
    config = YAML.load(File.open('config/application.yml'))
    @user = SocialQ::User.new({ :name             => 'Barack Obama', 
                                :twitter_user     => 'barackobama', 
                                :phone_number     => '+14155551212',
                                :channel          => 'twitter',
                                :twitter_username => config['twitter']['username'],
                                :twitter_password => config['twitter']['password'] })
  end
  
  it "should raise argument errors if a new user object is created without an option set" do
    begin
      result = SocialQ::User.new({ :foo => :bar })
    rescue => e
      e.to_s.should == 'A hash with the :name set is required.'
    end
    
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
    @user.name.should == 'Barack Obama'
    @user.twitter_user.should == 'barackobama'
    @user.phone_number.should == '+14155551212'
  end
  
  it "should have an user object should successfully transition through all of its state" do
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
end