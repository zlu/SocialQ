# billing_bridge_spec.rb
$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SocialQ::ContactQueue do
  before(:all) do
    @contact_queue = SocialQ::ContactQueue.new(1)
  end
  
  it 'should create a ContactQueue object' do
    @contact_queue.instance_of?(SocialQ::ContactQueue) == true
  end
  
  it 'should add an agent to the agents array' do
    @contact_queue.add_agent :foo => 'bar'
    @contact_queue.agents[0].should == { :foo => 'bar' }
  end
  
  it 'should add a user to the users array' do
    @contact_queue.add_user :foo => 'bar'
    @contact_queue.users[0].should == { :foo => 'bar' }
  end
  
  it 'should render a JSON string' do
    JSON.parse(@contact_queue.render_json).should == { "agents" => [ { "foo" => "bar"} ] , 
                                                       "users"  => [ { "foo" => "bar" } ] }
  end
end