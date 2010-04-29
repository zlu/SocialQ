$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SocialQ::Rabbit do
  before(:all) do
    config = YAML.load(File.open('config/application.yml'))
    @bunny = SocialQ::Rabbit.new(config['rabbit_mq'])
  end
  
  it 'should create a Bunny object' do
    @bunny.instance_of?(SocialQ::Rabbit) == true
  end
  
  it 'should publish and receive a message from socialq' do
    @bunny.publish_socialq({ :foo => 'bar' }.to_json)
    JSON.parse(@bunny.read_socialq).should == { 'foo' => 'bar' }
  end
  
  it 'should make available the agentq handle' do
    @bunny.agentq.instance_of?(Bunny::Queue)
  end
end