module SocialQ
  %w(aasm json tweetstream httparty tropo-webapi-ruby right_aws uuidtools).each { |lib| require lib }
  %w(socialq/agent socialq/session_queue socialq/tropo_handler socialq/user).each { |lib| require lib }
  %w(aws/sqs aws/sqs/client aws/sqs/queue).each { |lib| require lib }
end