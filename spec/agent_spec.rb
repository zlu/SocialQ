# billing_bridge_spec.rb
$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SocialContactCenter::Agent do
  before(:all) do
    @agent = SocialContactCenter::Agent.new({ :name => 'John Doe', :phone_number => '+14155551212' })
  end
  
  it "should raise argument errors if a new agent object is created without an option set" do
    begin
      result = SocialContactCenter::Agent.new({ :foo => :bar })
    rescue => e
      e.to_s.should == 'A hash with the :name set is required.'
    end
    
    begin
      result = SocialContactCenter::Agent.new({ :name => 'John Doe' })
    rescue => e
      e.to_s.should == 'A hash with the :phone_number set is required.'
    end
  end
  
  it "should create a new agent object with the appropriate values set" do
    @agent.name.should == 'John Doe'
    @agent.phone_number.should == '+14155551212'
  end
  
  it "should have an agent object should successfully transition through all of its state" do
    @agent.unavailable?.should == true
    @agent.make_available!
    @agent.available? == true
    @agent.make_unavailable!
    @agent.unavailable?.should == true
    @agent.make_available!
    @agent.send_call!
    @agent.unavailable?.should == true
  end
  
  it "should set the user to a new object" do
    @agent.set_user :foo => 'bar'
    @agent.user.should == { :foo => 'bar' }
  end
end