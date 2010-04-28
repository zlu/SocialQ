$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SocialQ::SessionQueue do
  before(:all) do
    @config = YAML.load(File.open('config/application.yml'))
    @session_queue = SocialQ::SessionQueue.new(@config['queue']['timer'],
                                               { :aws_access_key        => @config['amazon']['aws_access_key'],
                                                 :aws_secret_access_key => @config['amazon']['aws_secret_access_key'],
                                                 :endpoint              => @config['amazon']['endpoint'],
                                                 :session_sqs           => @config['amazon']['session_sqs'],
                                                 :agent_sqs             => @config['amazon']['agent_sqs'],
                                                 :db                    => @config['amazon']['db'] })
  end
  
  it 'should create a SessionQueue object' do
    @session_queue.instance_of?(SocialQ::SessionQueue) == true
  end
  
  it 'should add an agent to the agents array' do
     @config['agents'].each do |agent|
        @session_queue.add_agent(SocialQ::Agent.new({ :name => agent['name'],
                                                      :phone_number => agent['phone_number'] }))
      end
    @session_queue.agents[0].name.should == 'John Doe'
  end
  
  it 'should add a user to the users array' do
    @session_queue.add_user SocialQ::User.new({ :name               => 'Barack Obama',
                                                :twitter_user       => 'barackobama',
                                                :phone_number       => '+14155551212',
                                                :channel            => 'twitter',
                                                :twitter_username   => @config['twitter']['username'],
                                                :twitter_password   => @config['twitter']['password'],
                                                :twitter_keywords   => @config['twitter']['keywords'] })
    @session_queue.users[0].name.should == 'Barack Obama'
  end
  
  it 'should render a JSON string' do
    p @session_queue.render_json
    hash = JSON.parse(@session_queue.render_json)
    hash['agents'][0]['name'].should == 'John Doe'
  end
  
  it 'should have two instance methods that are an SQS queue' do
    @session_queue.session_sqs.name.should == 'sessions'
    @session_queue.agent_sqs.name.should == 'agents'
  end
end