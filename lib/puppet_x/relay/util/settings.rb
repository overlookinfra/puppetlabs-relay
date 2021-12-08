require 'forwardable'

require 'puppet'
require 'puppet/util'

require 'hiera/backend/eyaml/options'
require 'hiera/backend/eyaml/parser/parser'
require 'hiera/backend/eyaml/subcommand'

module PuppetX
  module Relay
    module Util
      class Settings
        include Enumerable

        # @param key [Symbol]
        def [](key); end

        def each
          enum_for(:each) unless block_given?
        end
      end

      class DefaultSettings < Settings
        extend Forwardable

        DEFAULTS = {
          debug: false,
          test: false,
          relay_api_url: 'https://api.relay.sh',
          relay_connection_token: nil,
          relay_trigger_token: nil,
          state_dir: '/var/run/puppetlabs/relay',
          backend: 'dummy',
          backend_orchestrator_api_url: "https://#{Puppet[:server]}:8143/orchestrator/v1/",
          backend_orchestrator_token: nil,
          backend_bolt_command: ['bolt'],
          backend_bolt_ssh_user: 'root',
          backend_bolt_ssh_password: nil,
          backend_bolt_ssh_host_key_check: true,
          backend_ssh_command: ['ssh'],
          proxy_host: nil,
          proxy_port: nil,
          proxy_user: nil,
          proxy_password: nil,
        }.freeze

        def_delegators "#{name}::DEFAULTS", :[], :each
      end

      class OverlaySettings < Settings
        # @param parent [Settings]
        # @param config [Hash<Symbol, Object>]
        def initialize(parent, config)
          @parent = parent
          @config = config
        end

        def [](key)
          @config.include?(key) ? @config[key] : @parent[key]
        end

        def each(&block)
          return enum_for(:each) unless block_given?

          @config.each(&block)
          @parent.each { |key, value| yield key, value unless @config.include?(key) }
        end
      end

      class FileSettings < OverlaySettings
        class HieraConfigurationError < StandardError; end

        attr_reader :file

        # @param file [String]
        def initialize(parent, file: nil)
          file ||= File.join(Puppet[:confdir], 'relay.yaml')
          super(parent, maybe_from_eyaml(YAML.load_file(file)).transform_keys(&:to_sym))
        rescue Errno::ENOENT
          super(parent, {})
        end

        private

        # @param data [Hash<Object, Object>]
        # @return [Hash<Object, Object>]
        def maybe_from_eyaml(data)
          cfg =
            begin
              Hiera::Backend::Eyaml::Subcommand.load_config_file
            rescue StandardError
              raise HieraConfigurationError, _('Could not read Hiera configuration')
            end

          return data if cfg[:sources].empty?

          # TODO: Is this safe to call globally?
          Hiera::Backend::Eyaml::Options.set(cfg[:options])

          parser = Hiera::Backend::Eyaml::Parser::ParserFactory.hiera_backend_parser
          transformer = proc do |value|
            if value.respond_to?(:transform_values)
              value.transform_values(&transformer)
            elsif value.respond_to?(:map)
              value.map(&transformer)
            elsif value.respond_to?(:chomp)
              toks = parser.parse(value.chomp)
              toks.map(&:to_plain_text).join
            else
              value
            end
          end

          transformer.call(data)
        end
      end

      class BackendOverlaySettings < OverlaySettings
        def initialize(parent, config)
          super(parent, config.transform_keys { |key| :"backend_#{parent[:backend]}_#{key}" })
        end
      end
    end
  end
end
