$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SocialQ::SessionQueue do
  before(:all) do
    @config = YAML.load(File.open('config/application.yml'))
    @session_queue = SocialQ::SessionQueue.new(@config['rabbit_mq'])
  end
  
  it 'should create a SessionQueue object' do
    @session_queue.instance_of?(SocialQ::SessionQueue) == true
  end
  
  it 'should add an agent to the agents array' do
     @config['agents'].each_with_index do |agent, index|
        @session_queue.add_agent(SocialQ::Agent.new({ :name         => agent['name'],
                                                      :phone_number => agent['phone_number'] }))
        @session_queue.agents[index].phone_number.should == agent['phone_number']
      end
  end
  
  it 'should add a user to the users array' do
    @session_queue.add_user SocialQ::User.new({ :twitter_user       => 'barackobama',
                                                :phone_number       => '+14155551212',
                                                :channel            => 'twitter',
                                                :twitter_username   => @config['twitter']['username'],
                                                :twitter_password   => @config['twitter']['password'],
                                                :twitter_keywords   => @config['twitter']['keywords'],
                                                :klout_key          => @config['twitter']['klout_key'],
                                                :weight_rules       => @config['weight_rules'],
                                                :queue_name         => '1234' })
    @session_queue.users[0].twitter_user.should == 'barackobama'
  end
  
  it 'should render a JSON string' do
    hash = JSON.parse(@session_queue.publish_json)
    hash['agents'][0]['name'].should == 'John Doe'
  end

  it 'should render a JSON string with two agents' do
    hash = JSON.parse(@session_queue.publish_json)
    hash['agents'].length == 2
  end
  
  it 'should render a JSON string with two users' do
    @session_queue.add_user SocialQ::User.new({ :twitter_user       => 'jsgoecke',
                                                :phone_number       => '+14155551212',
                                                :channel            => 'twitter',
                                                :twitter_username   => @config['twitter']['username'],
                                                :twitter_password   => @config['twitter']['password'],
                                                :twitter_keywords   => @config['twitter']['keywords'],
                                                :klout_key          => @config['twitter']['klout_key'],
                                                :weight_rules       => @config['weight_rules'],
                                                :queue_name         => '1234' })
    hash = JSON.parse(@session_queue.publish_json)
    hash['users'].length == 2
  end
  
  it 'should delete a user from the user array when requested' do
    guid = @session_queue.users[0].guid
    @session_queue.delete_user(guid)
    user = nil
    @session_queue.users.each do |u|
      user = u if u.guid == guid
      break
    end
    user.should == nil
  end
end