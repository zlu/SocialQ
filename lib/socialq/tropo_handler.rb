module SocialQ
  class TropoHandler
    
    ##
    # Transforms the Tropo JSON document received into the corresponding Tropo::Generator class
    #
    # @return [Hash] a Ruby hash of the Tropo message received
    def self.transform_response(json)
      Tropo::Generator.parse json
    end
    
  end
end