$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe AWS::SQS do
  before(:all) do
    @config = YAML.load(File.open('config/application.yml'))
    @client = AWS::SQS::Client.new(@config['amazon']['aws_access_key'], 
                                   @config['amazon']['aws_secret_access_key'], 
                                   :endpoint => @config['amazon']['endpoint'])
    @queue = @client.create_queue('sqs_test')
  end
  
  it "should connect to an Amazon queue as a client" do 
    @queue.name.should == 'sqs_test'
  end
  
  it "should write a message to the Amazon queue created" do
    message_id = @queue.send_message(CGI.escape({ :foo => 'bar' }.to_json))
    /^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$/.match(message_id).to_s.should == message_id
  end
  
  it "should read the message from the Amazon queue we just wrote to" do
    messages = @queue.receive_messages
    JSON.parse(CGI.unescape(messages[0]['Message'][0]['Body'][0])).should == { 'foo' => 'bar' }
  end
end