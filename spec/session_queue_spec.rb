# billing_bridge_spec.rb
$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SocialQ::SessionQueue do
  before(:all) do
    config = YAML.load(File.open('config/application.yml'))
    @session_queue = SocialQ::SessionQueue.new(config['queue']['timer'],
                                               { :aws_access_key        => config['amazon']['aws_access_key'],
                                                 :aws_secret_access_key => config['amazon']['aws_secret_access_key'],
                                                 :endpoint              => config['amazon']['endpoint'],
                                                 :session_sqs           => config['amazon']['session_sqs'],
                                                 :agent_sqs             => config['amazon']['agent_sqs'],  })
  end
  
  it 'should create a SessionQueue object' do
    @session_queue.instance_of?(SocialQ::SessionQueue) == true
  end
  
  it 'should add an agent to the agents array' do
    @session_queue.add_agent :foo => 'bar'
    @session_queue.agents[0].should == { :foo => 'bar' }
  end
  
  it 'should add a user to the users array' do
    @session_queue.add_user :foo => 'bar'
    @session_queue.users[0].should == { :foo => 'bar' }
  end
  
  it 'should render a JSON string' do
    JSON.parse(@session_queue.render_json).should == { "agents" => [ { "foo" => "bar"} ] , 
                                                       "users"  => [ { "foo" => "bar" } ] }
  end
end