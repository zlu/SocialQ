# billing_bridge_spec.rb
$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SocialQ::User::Topsy do
  it "should return a Ruby hash of author info" do
    SocialQ::User::Topsy::author_info('barackobama')['name'].should == 'Barack Obama'
  end
end

describe SocialQ::User do
  before(:all) do
    @agent = SocialQ::User.new({ :name         => 'Barack Obama', 
                                         :twitter_user => 'barackobama', 
                                         :phone_number => '+14155551212',
                                         :channel      => 'twitter' })
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
  
  it "should create a new user object with the appropriate values set" do
    @agent.name.should == 'Barack Obama'
    @agent.twitter_user.should == 'barackobama'
    @agent.phone_number.should == '+14155551212'
  end
  
  it "should have an user object should successfully transition through all of its state" do
    @agent.start?.should == true
    @agent.send_call!
    @agent.on_with_agent?.should == true
  end
  
  it "should set the agent to a new object" do
    @agent.set_agent :foo => 'bar'
    @agent.agent.should == { :foo => 'bar' }
  end
  
  it "should set the social_influence_rank" do
    @agent.social_influence_rank.should == 10
  end
end