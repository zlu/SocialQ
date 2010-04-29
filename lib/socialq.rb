module SocialQ
  %w(aasm json tweetstream httparty tropo-webapi-ruby right_aws uuidtools restclient).each { |lib| require lib }
  %w(socialq/agent socialq/session_queue socialq/tropo_handler socialq/user socialq/rabbit).each { |lib| require lib }
end