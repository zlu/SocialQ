# billing_bridge_spec.rb
$: << File.expand_path(File.dirname(__FILE__))

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SocialQ::TropoHandler do
  it "should render a Ruby hash from a JSON string sent by Tropo" do
    json = "{\"session\":{\"id\":\"dih06n\",\"accountId\":\"33932\",\"userType\":\"HUMAN\",\"to\":{\"id\":\"tropomessaging@bot.im\",\"name\":\"unknown\",\"channel\":\"TEXT\",\"network\":\"JABBER\"},\"from\":{\"id\":\"john_doe@gmail.com\",\"name\":\"unknown\",\"channel\":\"TEXT\",\"network\":\"JABBER\"}}}"
    hash = {:session=>{:user_type=>"HUMAN", :to=>{:channel=>"TEXT", :network=>"JABBER", :name=>"unknown", :id=>"tropomessaging@bot.im"}, :from=>{:channel=>"TEXT", :network=>"JABBER", :name=>"unknown", :id=>"john_doe@gmail.com"}, :account_id=>"33932", :id=>"dih06n"}}
    SocialQ::TropoHandler.transform_response(json).should == hash
  end
  
  
end
