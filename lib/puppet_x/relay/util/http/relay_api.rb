require 'puppet'

require_relative '../../agent/model'
require_relative 'client'

# rubocop:disable Style/AccessorMethodName

module PuppetX
  module Relay
    module Util
      module HTTP
        class RelayAPI < Client
          class MissingTokenError < StandardError; end

          def initialize(base_url, token, settings)
            super(base_url, settings)
            @token = token

            raise MissingTokenError unless @token
          end

          # @return [Array<Agent::Model::Stateful>]
          def get_runs
            resp = get('_puppet/runs')
            resp.value

            data = JSON.parse(resp.body)
            data['runs'].map { |run|
              case run['type']
              when 'run', nil
                Agent::Model::Run.from_h(run)
              when 'task-run'
                Agent::Model::TaskRun.from_h(run)
              when 'plan-run'
                Agent::Model::PlanRun.from_h(run)
              end
            }.compact
          end

          # @param run [Agent::Model::Stateful]
          # @return [Agent::Model::Stateful]
          def put_run_state(run)
            Puppet.debug(_('Updating run %{id} state to %{state}') % { id: run.id, state: run.state.inspect })
            resp = put("_puppet/runs/#{run.id}/state", body: run.state)
            resp.value

            data = JSON.parse(resp.body)
            run.with_state(Agent::Model::State.from_h(data))
          end

          # @param run [Agent::Model::Stateful]
          def post_accept_run(run)
            resp = post("_puppet/runs/#{run.id}/accept")
            resp.instance_of? Net::HTTPAccepted
          end

          # @param data [Hash]
          def emit_event(data)
            resp = post('api/events', body: { 'data' => data })
            resp.value
            resp
          end

          protected

          def update_request!(request)
            request['Authorization'] = "Bearer #{@token}"
          end
        end
      end
    end
  end
end
