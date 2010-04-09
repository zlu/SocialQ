$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe AWS::SQS do
  before(:all) do
    @config = YAML.load(File.open('config/application.yml'))
    @client = AWS::SQS::Client.new(@config['amazon']['aws_access_key'], 
                                   @config['amazon']['aws_secret_access_key'], 
                                   :endpoint => @config['amazon']['endpoint'])
    @queue = @client.create_queue('sqs_test')
    @time = Time.now.to_s
    @uuid = UUIDTools::UUID.random_create.to_s
    
    while true
      messages = @queue.receive_messages
      break if messages == [{}]
      messages.each { |message| @queue.delete_message(message["Message"][0]["ReceiptHandle"][0]) }
    end
  end
  
  after(:all) do
    while true
      messages = @queue.receive_messages
      break if messages == [{}]
      messages.each { |message| @queue.delete_message(message["Message"][0]["ReceiptHandle"][0]) }
    end
  end
  
  it "should connect to an Amazon queue as a client" do 
    @queue.name.should == 'sqs_test'
    queues = @client.list_queues
    queue_exists = false
    queues[0]['QueueUrl'].each { |queue| queue_exists = true if queue.gsub('http://queue.amazonaws.com/','') == 'sqs_test' }
    queue_exists.should == true
  end
  
  it "should write a message to the Amazon queue created" do
    message_id = @queue.send_message(CGI.escape({ :foobar => @time, :uuid => @uuid }.to_json))
    /^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$/.match(message_id).to_s.should == message_id
  end
  
  it "should read the message from the Amazon queue we just wrote to, while ignoring stale messages persisted to Amazon SDB" do
    sleep 2
    messages = @queue.receive_messages
    JSON.parse(CGI.unescape(messages[0]['Message'][0]['Body'][0])).should == { 'foobar' => @time, 'uuid' => @uuid }
  end
end