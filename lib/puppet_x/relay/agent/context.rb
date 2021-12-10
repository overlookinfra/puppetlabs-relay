require_relative 'backend'
require_relative '../util/http'
require_relative '../util/settings'

module PuppetX
  module Relay
    module Agent
      class Context
        # @return [Util::Settings]
        attr_reader :settings

        # @param settings [Util::Settings]
        def initialize(settings)
          @settings = settings
        end

        # @return [Util::HTTP::RelayAPI]
        def relay_api
          Util::HTTP::RelayAPI.new(settings[:relay_api_url], settings[:relay_connection_token], settings)
        end

        # @return [Backend::Base]
        def backend
          Backend.new_for_configuration(settings[:backend], relay_api, settings)
        end
      end
    end
  end
end
