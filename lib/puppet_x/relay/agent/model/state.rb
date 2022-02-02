require 'time'

require_relative '../error'

module PuppetX
  module Relay
    module Agent
      module Model
        class State
          class MissingStatusError < PuppetX::Relay::Agent::Error; end
          class InvalidTransitionError < PuppetX::Relay::Agent::Error; end

          class << self
            def from_h(hsh)
              hsh = hsh.dup

              hsh['status'] = hsh['status'].tr('-', '_').to_sym
              hsh['next_update_before'] = Time.iso8601(hsh['next_update_before']) if hsh.key? 'next_update_before'
              hsh['updated_at'] = Time.iso8601(hsh['updated_at']) if hsh.key? 'updated_at'

              new(hsh)
            end
          end

          # @return [:pending, :in_progress, :complete]
          attr_reader :status

          # @return [String]
          attr_reader :outcome

          # @return [String]
          attr_reader :run_results

          # @return [String]
          attr_reader :job_id

          # @return [Time]
          attr_reader :next_update_before

          # @return [Time]
          attr_reader :updated_at

          # @param opts [Hash]
          def initialize(opts)
            raise MissingStatusError unless opts.key? 'status'

            opts.each { |key, value| instance_variable_set("@#{key}", value) }
          end

          # @param outcome [String]
          # @param run_results [String]
          # @return [self]
          def to_complete(outcome: nil, run_results: nil)
            raise InvalidTransitionError, "Cannot transition status to complete from #{status}" unless [:pending, :in_progress].include? status

            upd = dup
            upd.instance_variable_set(:@status, :complete)
            upd.instance_variable_set(:@outcome, outcome)
            upd.instance_variable_set(:@run_results, run_results)
            upd.instance_variable_set(:@next_update_before, nil)
            upd
          end

          # @param next_update_before [Time]
          # @param job_id [String]
          # @return [self]
          def to_in_progress(next_update_before, job_id: nil)
            raise InvalidTransitionError, "Cannot transition status to in-progress from #{status}" unless [:pending, :in_progress].include? status

            upd = dup
            upd.instance_variable_set(:@status, :in_progress)
            upd.instance_variable_set(:@job_id, job_id) if job_id
            upd.instance_variable_set(:@next_update_before, next_update_before)
            upd
          end

          # @return [Hash]
          def to_h
            {
              'status' => status.to_s.tr('_', '-'),
              'outcome' => outcome,
              'run_results' => run_results,
              'job_id' => job_id,
              'next_update_before' => (next_update_before.utc.iso8601 unless next_update_before.nil?),
              'updated_at' => (updated_at.utc.iso8601 unless updated_at.nil?),
            }.reject { |_k, v| v.nil? }
          end

          # @return [String]
          def to_json(*args)
            to_h.to_json(*args)
          end
        end
      end
    end
  end
end
