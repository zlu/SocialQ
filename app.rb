$: << File.expand_path(File.dirname(__FILE__))
%w(rubygems logger restclient haml uri mongo).each { |lib| require lib }

# Load the configuration
APP_CONFIG = YAML.load(File.open('config/application.yml'))

# Start the logger
@@log = Logger.new(STDOUT)
@@log.level = Logger::DEBUG
@@log.info 'Starting SocialQ Sinatra App'

%w(sinatra tropo-webapi-ruby bunny json).each { |lib| require lib }

set :sessions, true
set :port, APP_CONFIG['sinatra']['port']
set :views, File.dirname(__FILE__) + '/templates'
set :haml, { :format => :html5 }

def connect_to_rabbit(queue)
  bunny = Bunny.new(:user    => APP_CONFIG['rabbit_mq']['user'],
                    :pass    => APP_CONFIG['rabbit_mq']['pass'],
                    :host    => APP_CONFIG['rabbit_mq']['host'],
                    :port    => APP_CONFIG['rabbit_mq']['port'],
                    :vhost   => APP_CONFIG['rabbit_mq']['vhost'],
                    :logging => APP_CONFIG['rabbit_mq']['logging'])
  bunny.start
  bunny.queue(APP_CONFIG['rabbit_mq'][queue])
end

# Setup Mongo connection
def connect_to_mongo
  uri = URI.parse(ENV['MONGOHQ_URL'])
  conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
  conn.db(uri.path.gsub(/^\//, ''))
end

def fetch_scenarios
  db = connect_to_mongo
  collection = db.collection('socialq_scenarios')  
  scenarios = []
  collection.find.each { |doc| scenarios << doc }
  scenarios[0].delete('_id')
  scenarios[0]
end

# Section or dealng wth Tropo WebAPI
post '/start.json' do
  tropo_event = Tropo::Generator.parse request.env["rack.input"].read
  if tropo_event['session']['parameters']
    tropo = Tropo::Generator.new do
      on :event => 'error', :next => '/error.json'
      call({ :to              => 'tel:+' + tropo_event.session.parameters.phone_number, 
             :from            => '6172977928',
             :network         => 'PSTN',
             :channel         => 'VOICE',
             :timeout         => 30,
             :answer_on_media => false })
      say "Nous sommes sur le point de vous connecter, s'il vous plaît attendre.", :voice => 'florence'
      conference :id => tropo_event.session.parameters.queue_name, :name => 'SocialQ', :beep => false
    end
    tropo.response
  else
    callq = connect_to_rabbit('callq')
  
    if tropo_event.session.from.channel == 'VOICE'
      time = Time.now.to_i.to_s
      tropo = Tropo::Generator.new do
        on :event => 'hangup', :next => '/hangup.json'
        say "Merci de votre appel, s'il vous plaît patienter pendant que nous trouver un agent pour vous.", :voice => 'florence'
        conference :id        => time, 
                   :name      => 'SocialQ', 
                   :sendTones => false, 
                   :beep      => false, 
                   :choices   => 'foo, bar'
      end
      queue_message = tropo_event.merge!({ :queue_name => time })
      callq.publish(queue_message.to_json)
      tropo.response
    else
      callq.publish(tropo_event.to_json)
    end
  end
end

post '/error.json' do
  p Tropo::Generator.parse request.env["rack.input"].read
end

post '/hangup.json' do
  p Tropo::Generator.parse request.env["rack.input"].read
end

# Section for dealing with RESTful Rabbit Interface
get '/messages' do
  socialq = connect_to_rabbit('socialq')
  
  messages = Array.new
  msg = nil
  while msg != :queue_empty
    msg = socialq.pop[:payload]
    if msg != :queue_empty
      messages << JSON.parse(msg)
    end
  end
  messages.to_json
end

get '/dump' do
  dumpq = connect_to_rabbit('dumpq')
  
  messages = Array.new
  msg = nil
  while msg != :queue_empty
    msg = dumpq.pop[:payload]
    if msg != :queue_empty
      messages << JSON.parse(msg)
    end
  end
  messages.to_json
end

post '/publish_message' do
  socialq = connect_to_rabbit('socialq')
  socialq.publish(request.env["rack.input"].read)
end

post '/agent_ready' do
  agentq = connect_to_rabbit('agentq')
  agentq.publish(request.env["rack.input"].read)
end

get '/reset' do
  resetq = connect_to_rabbit('resetq')
  resetq.publish({ :action => 'reset' }.to_json)
  haml :reset
end

get '/scenarios' do
  @scenarios = fetch_scenarios
  @@log.info @scenarios.inspect
  haml :scenarios
end

get '/scenario/:scenario' do |scenario|
  @scenario, session['scenario'] = scenario, scenario
  scenarios = fetch_scenarios
  @possible_scenarios = ''
  scenarios.each { |k, v| 
    @possible_scenarios += k + ' '
  }
  @messages = scenarios[scenario]
  
  if @messages
    haml :scenario
  else
    haml :unkown
  end
end

get '/posts/:message_number' do |message_number|
  socialq = connect_to_rabbit('dumpq')
  scenarios = fetch_scenarios
  socialq.publish(scenarios[session['scenario']][message_number.to_i].to_json)
  redirect "/scenario/#{session['scenario']}"
end

get '/load_scenario' do
  messages = []
  messages << {"agents"=>[], "users"=>[{"klout"=>{"result"=>"Not found"}, "guid"=>"2e7e9155-865d-4fa2-800e-441be3013bf7", "queue_name"=>"1273697421", "tweet_watchword"=>nil, "time"=>"Wed May 12 13:50:21 -0700 2010", "phone_number"=>"4074181800", "channel"=>"phone", "queue_weight"=>10, "social_influence_rank"=>0, "twitter_profile"=>{"profile_background_tile"=>true, "profile_sidebar_fill_color"=>"DDEEF6", "profile_sidebar_border_color"=>"C0DEED", "name"=>"LenosSquirrel", "created_at"=>"Thu Mar 11 01:12:27 +0000 2010", "profile_image_url"=>"http://a1.twimg.com/profile_images/745430850/squirrel_normal.jpg", "location"=>"Malibu", "profile_link_color"=>"0084B4", "contributors_enabled"=>false, "url"=>nil, "favourites_count"=>0, "id"=>121916400, "utc_offset"=>-28800, "lang"=>"en", "followers_count"=>2, "protected"=>false, "profile_text_color"=>"333333", "description"=>"Glad Leno stays out later these days.", "notifications"=>false, "geo_enabled"=>false, "profile_background_color"=>"C0DEED", "time_zone"=>"Pacific Time (US & Canada)", "verified"=>false, "profile_background_image_url"=>"http://a1.twimg.com/profile_background_images/82164118/acorn_large.jpg", "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 20:44:11 +0000 2010", "contributors"=>nil, "text"=>"I am tired of being in queue! #fail", "id"=>13870917469, "geo"=>nil, "in_reply_to_user_id"=>nil, "source"=>"<a href=\"http://www.atebits.com/\" rel=\"nofollow\">Tweetie</a>", "place"=>nil, "in_reply_to_screen_name"=>nil, "in_reply_to_status_id"=>nil}, "statuses_count"=>51, "friends_count"=>5, "following"=>false, "screen_name"=>"LenosSquirrel"}}]}
  messages << {"agents"=>[], "users"=>[{"klout"=>{"result"=>"Not found"}, "guid"=>"2e7e9155-865d-4fa2-800e-441be3013bf7", "queue_name"=>"1273697421", "tweet_watchword"=>nil, "time"=>"Wed May 12 13:50:21 -0700 2010", "phone_number"=>"4074181800", "channel"=>"phone", "queue_weight"=>10, "social_influence_rank"=>0, "twitter_profile"=>{"profile_background_tile"=>true, "profile_sidebar_fill_color"=>"DDEEF6", "profile_sidebar_border_color"=>"C0DEED", "name"=>"LenosSquirrel", "created_at"=>"Thu Mar 11 01:12:27 +0000 2010", "profile_image_url"=>"http://a1.twimg.com/profile_images/745430850/squirrel_normal.jpg", "location"=>"Malibu", "profile_link_color"=>"0084B4", "contributors_enabled"=>false, "url"=>nil, "favourites_count"=>0, "id"=>121916400, "utc_offset"=>-28800, "lang"=>"en", "followers_count"=>2, "protected"=>false, "profile_text_color"=>"333333", "description"=>"Glad Leno stays out later these days.", "notifications"=>false, "geo_enabled"=>false, "profile_background_color"=>"C0DEED", "time_zone"=>"Pacific Time (US & Canada)", "verified"=>false, "profile_background_image_url"=>"http://a1.twimg.com/profile_background_images/82164118/acorn_large.jpg", "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 20:44:11 +0000 2010", "contributors"=>nil, "text"=>"I am tired of being in queue! #fail", "id"=>13870917469, "geo"=>nil, "in_reply_to_user_id"=>nil, "source"=>"<a href=\"http://www.atebits.com/\" rel=\"nofollow\">Tweetie</a>", "place"=>nil, "in_reply_to_screen_name"=>nil, "in_reply_to_status_id"=>nil}, "statuses_count"=>51, "friends_count"=>5, "following"=>false, "screen_name"=>"LenosSquirrel"}}, {"klout"=>{"twitter_screen_name"=>"aplusk", "twitter_id"=>"19058681", "score"=>{"kscore"=>83.94, "kclass_description"=>"You have built a personal brand around your identity. There is a good chance that you work in social media or marketing but you might even be famous in real life. Being a persona is not just about having a ton of followers, to make it to the top right corner you need to engage with your audience. Make no mistake about it though, when you talk people listen.", "slope"=>-0.08, "amplification_score"=>76.15, "network_score"=>86.27, "kscore_description"=>nil, "true_reach"=>1928961, "kclass"=>"persona"}}, "guid"=>"c6d6dae0-f5f0-4c27-a3c6-669fcafa8295", "queue_name"=>"1273697438", "tweet_watchword"=>nil, "time"=>"Wed May 12 13:50:38 -0700 2010", "phone_number"=>"jsgoecke", "channel"=>"phone", "queue_weight"=>177.88, "social_influence_rank"=>10, "twitter_profile"=>{"profile_background_tile"=>true, "profile_sidebar_fill_color"=>"DDFFCC", "profile_sidebar_border_color"=>"BDDCAD", "name"=>"ashton kutcher", "created_at"=>"Fri Jan 16 07:40:06 +0000 2009", "profile_image_url"=>"http://a1.twimg.com/profile_images/638714290/profile_pic_normal.jpg", "location"=>"Los Angeles, California", "profile_link_color"=>"8f000e", "favourites_count"=>73, "url"=>"http://www.facebook.com/Ashton", "contributors_enabled"=>false, "id"=>19058681, "utc_offset"=>-18000, "lang"=>"en", "protected"=>false, "followers_count"=>4882753, "profile_text_color"=>"333333", "description"=>"I make stuff, actually I make up stuff, stories mostly, collaborations of thoughts, dreams, and actions. Thats me.", "geo_enabled"=>false, "notifications"=>false, "verified"=>true, "time_zone"=>"Eastern Time (US & Canada)", "profile_background_color"=>"9AE4E8", "friends_count"=>552, "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 03:01:27 +0000 2010", "contributors"=>nil, "text"=>"Watch the 1 girl in the back row that realizes she's witnessing a future superstar in the making AMAZING-&gt; http://bit.ly/b8Ie3M", "id"=>13827306741, "geo"=>nil, "in_reply_to_user_id"=>nil, "source"=>"<a href=\"http://www.brizzly.com\" rel=\"nofollow\">Brizzly</a>", "place"=>nil, "in_reply_to_screen_name"=>nil, "in_reply_to_status_id"=>nil}, "statuses_count"=>5381, "profile_background_image_url"=>"http://a3.twimg.com/profile_background_images/56586067/Picture_4.png", "following"=>false, "screen_name"=>"aplusk"}}]}
  messages << {"agents"=>[], "users"=>[{"klout"=>{"result"=>"Not found"}, "guid"=>"2e7e9155-865d-4fa2-800e-441be3013bf7", "queue_name"=>"1273697421", "tweet_watchword"=>"fail", "time"=>"Wed May 12 13:50:21 -0700 2010", "phone_number"=>"4074181800", "channel"=>"phone", "queue_weight"=>15, "social_influence_rank"=>0, "twitter_profile"=>{"profile_background_tile"=>true, "profile_sidebar_fill_color"=>"DDEEF6", "profile_sidebar_border_color"=>"C0DEED", "name"=>"LenosSquirrel", "created_at"=>"Thu Mar 11 01:12:27 +0000 2010", "profile_image_url"=>"http://a1.twimg.com/profile_images/745430850/squirrel_normal.jpg", "location"=>"Malibu", "profile_link_color"=>"0084B4", "contributors_enabled"=>false, "url"=>nil, "favourites_count"=>0, "id"=>121916400, "utc_offset"=>-28800, "lang"=>"en", "followers_count"=>2, "protected"=>false, "profile_text_color"=>"333333", "description"=>"Glad Leno stays out later these days.", "notifications"=>false, "geo_enabled"=>false, "profile_background_color"=>"C0DEED", "time_zone"=>"Pacific Time (US & Canada)", "verified"=>false, "profile_background_image_url"=>"http://a1.twimg.com/profile_background_images/82164118/acorn_large.jpg", "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 20:44:11 +0000 2010", "contributors"=>nil, "text"=>"I am tired of being in queue! #fail", "id"=>13870917469, "geo"=>nil, "in_reply_to_user_id"=>nil, "source"=>"<a href=\"http://www.atebits.com/\" rel=\"nofollow\">Tweetie</a>", "place"=>nil, "in_reply_to_screen_name"=>nil, "in_reply_to_status_id"=>nil}, "statuses_count"=>51, "friends_count"=>5, "following"=>false, "screen_name"=>"LenosSquirrel"}}, {"klout"=>{"twitter_screen_name"=>"aplusk", "twitter_id"=>"19058681", "score"=>{"kscore"=>83.94, "kclass_description"=>"You have built a personal brand around your identity. There is a good chance that you work in social media or marketing but you might even be famous in real life. Being a persona is not just about having a ton of followers, to make it to the top right corner you need to engage with your audience. Make no mistake about it though, when you talk people listen.", "slope"=>-0.08, "amplification_score"=>76.15, "network_score"=>86.27, "kscore_description"=>nil, "true_reach"=>1928961, "kclass"=>"persona"}}, "guid"=>"c6d6dae0-f5f0-4c27-a3c6-669fcafa8295", "queue_name"=>"1273697438", "tweet_watchword"=>nil, "time"=>"Wed May 12 13:50:38 -0700 2010", "phone_number"=>"jsgoecke", "channel"=>"phone", "queue_weight"=>177.88, "social_influence_rank"=>10, "twitter_profile"=>{"profile_background_tile"=>true, "profile_sidebar_fill_color"=>"DDFFCC", "profile_sidebar_border_color"=>"BDDCAD", "name"=>"ashton kutcher", "created_at"=>"Fri Jan 16 07:40:06 +0000 2009", "profile_image_url"=>"http://a1.twimg.com/profile_images/638714290/profile_pic_normal.jpg", "location"=>"Los Angeles, California", "profile_link_color"=>"8f000e", "favourites_count"=>73, "url"=>"http://www.facebook.com/Ashton", "contributors_enabled"=>false, "id"=>19058681, "utc_offset"=>-18000, "lang"=>"en", "protected"=>false, "followers_count"=>4882753, "profile_text_color"=>"333333", "description"=>"I make stuff, actually I make up stuff, stories mostly, collaborations of thoughts, dreams, and actions. Thats me.", "geo_enabled"=>false, "notifications"=>false, "verified"=>true, "time_zone"=>"Eastern Time (US & Canada)", "profile_background_color"=>"9AE4E8", "friends_count"=>552, "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 03:01:27 +0000 2010", "contributors"=>nil, "text"=>"Watch the 1 girl in the back row that realizes she's witnessing a future superstar in the making AMAZING-&gt; http://bit.ly/b8Ie3M", "id"=>13827306741, "geo"=>nil, "in_reply_to_user_id"=>nil, "source"=>"<a href=\"http://www.brizzly.com\" rel=\"nofollow\">Brizzly</a>", "place"=>nil, "in_reply_to_screen_name"=>nil, "in_reply_to_status_id"=>nil}, "statuses_count"=>5381, "profile_background_image_url"=>"http://a3.twimg.com/profile_background_images/56586067/Picture_4.png", "following"=>false, "screen_name"=>"aplusk"}}]}
  messages << {"agents"=>[], "users"=>[{"klout"=>{"result"=>"Not found"}, "guid"=>"2e7e9155-865d-4fa2-800e-441be3013bf7", "queue_name"=>"1273697421", "tweet_watchword"=>"fail", "time"=>"Wed May 12 13:50:21 -0700 2010", "phone_number"=>"4074181800", "channel"=>"phone", "queue_weight"=>20, "social_influence_rank"=>0, "twitter_profile"=>{"profile_background_tile"=>true, "profile_sidebar_fill_color"=>"DDEEF6", "profile_sidebar_border_color"=>"C0DEED", "name"=>"LenosSquirrel", "created_at"=>"Thu Mar 11 01:12:27 +0000 2010", "profile_image_url"=>"http://a1.twimg.com/profile_images/745430850/squirrel_normal.jpg", "location"=>"Malibu", "profile_link_color"=>"0084B4", "contributors_enabled"=>false, "url"=>nil, "favourites_count"=>0, "id"=>121916400, "utc_offset"=>-28800, "lang"=>"en", "followers_count"=>2, "protected"=>false, "profile_text_color"=>"333333", "description"=>"Glad Leno stays out later these days.", "notifications"=>false, "geo_enabled"=>false, "profile_background_color"=>"C0DEED", "time_zone"=>"Pacific Time (US & Canada)", "verified"=>false, "profile_background_image_url"=>"http://a1.twimg.com/profile_background_images/82164118/acorn_large.jpg", "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 20:44:11 +0000 2010", "contributors"=>nil, "text"=>"I am tired of being in queue! #fail", "id"=>13870917469, "geo"=>nil, "in_reply_to_user_id"=>nil, "source"=>"<a href=\"http://www.atebits.com/\" rel=\"nofollow\">Tweetie</a>", "place"=>nil, "in_reply_to_screen_name"=>nil, "in_reply_to_status_id"=>nil}, "statuses_count"=>51, "friends_count"=>5, "following"=>false, "screen_name"=>"LenosSquirrel"}}, {"klout"=>{"twitter_screen_name"=>"aplusk", "twitter_id"=>"19058681", "score"=>{"kscore"=>83.94, "kclass_description"=>"You have built a personal brand around your identity. There is a good chance that you work in social media or marketing but you might even be famous in real life. Being a persona is not just about having a ton of followers, to make it to the top right corner you need to engage with your audience. Make no mistake about it though, when you talk people listen.", "slope"=>-0.08, "amplification_score"=>76.15, "network_score"=>86.27, "kscore_description"=>nil, "true_reach"=>1928961, "kclass"=>"persona"}}, "guid"=>"c6d6dae0-f5f0-4c27-a3c6-669fcafa8295", "queue_name"=>"1273697438", "tweet_watchword"=>nil, "time"=>"Wed May 12 13:50:38 -0700 2010", "phone_number"=>"jsgoecke", "channel"=>"phone", "queue_weight"=>177.88, "social_influence_rank"=>10, "twitter_profile"=>{"profile_background_tile"=>true, "profile_sidebar_fill_color"=>"DDFFCC", "profile_sidebar_border_color"=>"BDDCAD", "name"=>"ashton kutcher", "created_at"=>"Fri Jan 16 07:40:06 +0000 2009", "profile_image_url"=>"http://a1.twimg.com/profile_images/638714290/profile_pic_normal.jpg", "location"=>"Los Angeles, California", "profile_link_color"=>"8f000e", "favourites_count"=>73, "url"=>"http://www.facebook.com/Ashton", "contributors_enabled"=>false, "id"=>19058681, "utc_offset"=>-18000, "lang"=>"en", "protected"=>false, "followers_count"=>4882753, "profile_text_color"=>"333333", "description"=>"I make stuff, actually I make up stuff, stories mostly, collaborations of thoughts, dreams, and actions. Thats me.", "geo_enabled"=>false, "notifications"=>false, "verified"=>true, "time_zone"=>"Eastern Time (US & Canada)", "profile_background_color"=>"9AE4E8", "friends_count"=>552, "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 03:01:27 +0000 2010", "contributors"=>nil, "text"=>"Watch the 1 girl in the back row that realizes she's witnessing a future superstar in the making AMAZING-&gt; http://bit.ly/b8Ie3M", "id"=>13827306741, "geo"=>nil, "in_reply_to_user_id"=>nil, "source"=>"<a href=\"http://www.brizzly.com\" rel=\"nofollow\">Brizzly</a>", "place"=>nil, "in_reply_to_screen_name"=>nil, "in_reply_to_status_id"=>nil}, "statuses_count"=>5381, "profile_background_image_url"=>"http://a3.twimg.com/profile_background_images/56586067/Picture_4.png", "following"=>false, "screen_name"=>"aplusk"}}, {"klout"=>{"twitter_screen_name"=>"squirrelrific", "twitter_id"=>"128687136", "score"=>{"kscore"=>5.07, "kclass_description"=>"You are building an audience and finding your voice. Engaging more with others and building trust will help you move towards the upper right corner and then into the Persona quadrant. On the flip side, however, corporate broadcasters and spammers often find themselves in the lower right corner with a relatively large audience but no influence.", "slope"=>0, "amplification_score"=>3.35, "network_score"=>1, "kscore_description"=>nil, "true_reach"=>0, "kclass"=>"climber"}}, "guid"=>"21219c8b-140a-4365-8e4c-1a173c79a013", "queue_name"=>"twitter", "tweet_watchword"=>nil, "time"=>"Wed May 12 13:51:55 -0700 2010", "phone_number"=>"14153675082", "channel"=>"twitter", "queue_weight"=>18.14, "social_influence_rank"=>0, "twitter_profile"=>{"profile_background_tile"=>false, "profile_sidebar_fill_color"=>"e0ff92", "profile_sidebar_border_color"=>"87bc44", "name"=>"Squirrel", "created_at"=>"Thu Apr 01 22:15:06 +0000 2010", "profile_image_url"=>"http://a1.twimg.com/profile_images/871024140/E6B92E01-E3BA-EE24-5023D760559DCFDA_normal.jpg", "location"=>"", "profile_link_color"=>"0000ff", "favourites_count"=>0, "contributors_enabled"=>false, "url"=>nil, "id"=>128687136, "utc_offset"=>nil, "lang"=>"en", "protected"=>false, "followers_count"=>0, "profile_text_color"=>"000000", "description"=>"", "notifications"=>false, "geo_enabled"=>false, "verified"=>false, "time_zone"=>nil, "profile_background_color"=>"9ae4e8", "friends_count"=>0, "statuses_count"=>30, "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 20:51:35 +0000 2010", "contributors"=>nil, "text"=>"@TogetherMore Get me some nuts, eh?", "id"=>13871242778, "geo"=>nil, "in_reply_to_user_id"=>141355590, "source"=>"<a href=\"http://www.atebits.com/\" rel=\"nofollow\">Tweetie</a>", "place"=>nil, "in_reply_to_screen_name"=>"TogetherMore", "in_reply_to_status_id"=>nil}, "profile_background_image_url"=>"http://s.twimg.com/a/1273278095/images/themes/theme1/bg.png", "following"=>false, "screen_name"=>"squirrelrific"}}]}
  messages << {"agents"=>[], "users"=>[{"klout"=>{"result"=>"Not found"}, "guid"=>"2e7e9155-865d-4fa2-800e-441be3013bf7", "queue_name"=>"1273697421", "tweet_watchword"=>"fail", "time"=>"Wed May 12 13:50:21 -0700 2010", "phone_number"=>"4074181800", "channel"=>"phone", "queue_weight"=>20, "social_influence_rank"=>0, "twitter_profile"=>{"profile_background_tile"=>true, "profile_sidebar_fill_color"=>"DDEEF6", "profile_sidebar_border_color"=>"C0DEED", "name"=>"LenosSquirrel", "created_at"=>"Thu Mar 11 01:12:27 +0000 2010", "profile_image_url"=>"http://a1.twimg.com/profile_images/745430850/squirrel_normal.jpg", "location"=>"Malibu", "profile_link_color"=>"0084B4", "contributors_enabled"=>false, "url"=>nil, "favourites_count"=>0, "id"=>121916400, "utc_offset"=>-28800, "lang"=>"en", "followers_count"=>2, "protected"=>false, "profile_text_color"=>"333333", "description"=>"Glad Leno stays out later these days.", "notifications"=>false, "geo_enabled"=>false, "profile_background_color"=>"C0DEED", "time_zone"=>"Pacific Time (US & Canada)", "verified"=>false, "profile_background_image_url"=>"http://a1.twimg.com/profile_background_images/82164118/acorn_large.jpg", "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 20:44:11 +0000 2010", "contributors"=>nil, "text"=>"I am tired of being in queue! #fail", "id"=>13870917469, "geo"=>nil, "in_reply_to_user_id"=>nil, "source"=>"<a href=\"http://www.atebits.com/\" rel=\"nofollow\">Tweetie</a>", "place"=>nil, "in_reply_to_screen_name"=>nil, "in_reply_to_status_id"=>nil}, "statuses_count"=>51, "friends_count"=>5, "following"=>false, "screen_name"=>"LenosSquirrel"}}, {"klout"=>{"twitter_screen_name"=>"aplusk", "twitter_id"=>"19058681", "score"=>{"kscore"=>83.94, "kclass_description"=>"You have built a personal brand around your identity. There is a good chance that you work in social media or marketing but you might even be famous in real life. Being a persona is not just about having a ton of followers, to make it to the top right corner you need to engage with your audience. Make no mistake about it though, when you talk people listen.", "slope"=>-0.08, "amplification_score"=>76.15, "network_score"=>86.27, "kscore_description"=>nil, "true_reach"=>1928961, "kclass"=>"persona"}}, "guid"=>"c6d6dae0-f5f0-4c27-a3c6-669fcafa8295", "queue_name"=>"1273697438", "tweet_watchword"=>nil, "time"=>"Wed May 12 13:50:38 -0700 2010", "phone_number"=>"jsgoecke", "channel"=>"phone", "queue_weight"=>177.88, "social_influence_rank"=>10, "twitter_profile"=>{"profile_background_tile"=>true, "profile_sidebar_fill_color"=>"DDFFCC", "profile_sidebar_border_color"=>"BDDCAD", "name"=>"ashton kutcher", "created_at"=>"Fri Jan 16 07:40:06 +0000 2009", "profile_image_url"=>"http://a1.twimg.com/profile_images/638714290/profile_pic_normal.jpg", "location"=>"Los Angeles, California", "profile_link_color"=>"8f000e", "favourites_count"=>73, "url"=>"http://www.facebook.com/Ashton", "contributors_enabled"=>false, "id"=>19058681, "utc_offset"=>-18000, "lang"=>"en", "protected"=>false, "followers_count"=>4882753, "profile_text_color"=>"333333", "description"=>"I make stuff, actually I make up stuff, stories mostly, collaborations of thoughts, dreams, and actions. Thats me.", "geo_enabled"=>false, "notifications"=>false, "verified"=>true, "time_zone"=>"Eastern Time (US & Canada)", "profile_background_color"=>"9AE4E8", "friends_count"=>552, "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 03:01:27 +0000 2010", "contributors"=>nil, "text"=>"Watch the 1 girl in the back row that realizes she's witnessing a future superstar in the making AMAZING-&gt; http://bit.ly/b8Ie3M", "id"=>13827306741, "geo"=>nil, "in_reply_to_user_id"=>nil, "source"=>"<a href=\"http://www.brizzly.com\" rel=\"nofollow\">Brizzly</a>", "place"=>nil, "in_reply_to_screen_name"=>nil, "in_reply_to_status_id"=>nil}, "statuses_count"=>5381, "profile_background_image_url"=>"http://a3.twimg.com/profile_background_images/56586067/Picture_4.png", "following"=>false, "screen_name"=>"aplusk"}}, {"klout"=>{"twitter_screen_name"=>"squirrelrific", "twitter_id"=>"128687136", "score"=>{"kscore"=>5.07, "kclass_description"=>"You are building an audience and finding your voice. Engaging more with others and building trust will help you move towards the upper right corner and then into the Persona quadrant. On the flip side, however, corporate broadcasters and spammers often find themselves in the lower right corner with a relatively large audience but no influence.", "slope"=>0, "amplification_score"=>3.35, "network_score"=>1, "kscore_description"=>nil, "true_reach"=>0, "kclass"=>"climber"}}, "guid"=>"21219c8b-140a-4365-8e4c-1a173c79a013", "queue_name"=>"twitter", "tweet_watchword"=>"fail", "time"=>"Wed May 12 13:51:55 -0700 2010", "phone_number"=>"14153675082", "channel"=>"twitter", "queue_weight"=>23.14, "social_influence_rank"=>0, "twitter_profile"=>{"profile_background_tile"=>false, "profile_sidebar_fill_color"=>"e0ff92", "profile_sidebar_border_color"=>"87bc44", "name"=>"Squirrel", "created_at"=>"Thu Apr 01 22:15:06 +0000 2010", "profile_image_url"=>"http://a1.twimg.com/profile_images/871024140/E6B92E01-E3BA-EE24-5023D760559DCFDA_normal.jpg", "location"=>"", "profile_link_color"=>"0000ff", "favourites_count"=>0, "contributors_enabled"=>false, "url"=>nil, "id"=>128687136, "utc_offset"=>nil, "lang"=>"en", "protected"=>false, "followers_count"=>0, "profile_text_color"=>"000000", "description"=>"", "notifications"=>false, "geo_enabled"=>false, "verified"=>false, "time_zone"=>nil, "profile_background_color"=>"9ae4e8", "friends_count"=>0, "statuses_count"=>30, "status"=>{"coordinates"=>nil, "favorited"=>false, "truncated"=>false, "created_at"=>"Wed May 12 20:51:35 +0000 2010", "contributors"=>nil, "text"=>"@TogetherMore Get me some nuts, eh?", "id"=>13871242778, "geo"=>nil, "in_reply_to_user_id"=>141355590, "source"=>"<a href=\"http://www.atebits.com/\" rel=\"nofollow\">Tweetie</a>", "place"=>nil, "in_reply_to_screen_name"=>"TogetherMore", "in_reply_to_status_id"=>nil}, "profile_background_image_url"=>"http://s.twimg.com/a/1273278095/images/themes/theme1/bg.png", "following"=>false, "screen_name"=>"squirrelrific"}}]}
  
  db = connect_to_mongo
  collection = db.collection('socialq_scenarios')
  collection.remove
  collection.insert({ :basic_squirrel => messages })
  results = []
  collection.find.each { |doc| results << doc.inspect }
  results.inspect
end