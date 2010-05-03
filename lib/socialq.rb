$: << File.expand_path(File.dirname(__FILE__))
module SocialQ
  %w(json tweetstream httparty tropo-webapi-ruby right_aws uuidtools restclient observer).each { |lib| require lib }
  %w(socialq/agent socialq/session_queue socialq/tropo_handler socialq/user socialq/rabbit).each { |lib| require lib }
end