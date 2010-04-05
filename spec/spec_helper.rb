$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
%w(rubygems spec spec/autorun lib/user lib/agent lib/contact_queue.rb json).each { |lib| require lib }

Spec::Runner.configure do |config|
  
end
