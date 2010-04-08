module SocialQ
  class TropoHandler
    
    def self.transform_response(json)
      Tropo::Generator.parse json
    end
    
  end
end