%w(rubygems right_aws lib/aws/sqs lib/aws/sqs/client lib/aws/sqs/queue).each { |lib| require lib }

config = YAML.load(File.open('config/application.yml'))

# First clear SDB
sdb = RightAws::SdbInterface.new(config['amazon']['aws_access_key'],
                                 config['amazon']['aws_secret_access_key'],
                                 { :multi_thread => false })

domain_exists = false
sdb.list_domains[:domains].each { |domain| domain_exists == true if domain == 'SocialQ' }
sdb.create_domain('SocialQ') unless domain_exists

attributes = { :ids => [ '0000' ]  }
sdb.delete_attributes 'SocialQ', 'stale_messages'
sdb.put_attributes 'SocialQ', 'stale_messages', attributes
p 'Flushed: '
p sdb.get_attributes 'SocialQ', 'stale_messages'
p '*'*10

# Now clear SQS
@client = AWS::SQS::Client.new(config['amazon']['aws_access_key'], 
                               config['amazon']['aws_secret_access_key'], 
                               :endpoint => config['amazon']['endpoint'])

def clean_queue(queue)
  queue = @client.create_queue(queue)

  while true
    messages = queue.receive_messages
    break if messages == [{}] 
    messages.each do |message|
      p message
      p '='*5
      queue.delete_message(message["Message"][0]["ReceiptHandle"][0]) if message != {}
    end
  end
end
                              
p 'Cleaning ' + config['amazon']['session_sqs']
clean_queue config['amazon']['session_sqs']
p '*'*10

p 'Cleaning ' + config['amazon']['agent_sqs']
clean_queue config['amazon']['agent_sqs']
p '*'*10

p 'Cleaning ' + 'sqs_test'
clean_queue 'sqs_test'
p '*'*10
