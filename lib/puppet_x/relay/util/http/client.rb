require 'net/http'

module PuppetX
  module Relay
    module Util
      module HTTP
        class Client
          def initialize(base_url, settings = nil)
            @base_url = base_url
            @proxy_host = settings[:proxy_host] if settings
            @proxy_port = settings[:proxy_port] if settings
            @proxy_user = settings[:proxy_user] if settings
            @proxy_password = settings[:proxy_password] if settings
          end

          # @param verb [Symbol]
          # @param path [String]
          # @return [Net::HTTPResponse]
          def request(verb, path, body: nil)
            uri = URI.join(@base_url, path)

            req = Object.const_get("Net::HTTP::#{verb.to_s.capitalize}").new(uri)
            req['Content-Type'] = 'application/json'
            req.body = body.to_json if body

            update_request!(req)

            http = Net::HTTP.new(uri.host, uri.port, @proxy_host, @proxy_port, @proxy_user, @proxy_password)
            http.use_ssl = uri.scheme == 'https'
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            update_http!(http)

            http.start { |sess| sess.request(req) }
          end

          def get(path)
            request(:get, path)
          end

          def post(path, body: nil)
            request(:post, path, body: body)
          end

          def put(path, body: nil)
            request(:put, path, body: body)
          end

          protected

          # @param http [Net::HTTP]
          def update_http!(http); end

          # @param request [Net::HTTPGenericRequest]
          def update_request!(request); end
        end
      end
    end
  end
end
