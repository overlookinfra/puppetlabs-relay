require 'puppet'
require 'puppet/util/pidlock'

require_relative '../backend'
require_relative '../model'
require_relative 'base'
require_relative 'schedule'

module PuppetX
  module Relay
    module Agent
      module Job
        class Exec < Base
          # @param backend [Backend::Base]
          # @param run [Model::Stateful]
          # @param state_dir [String]
          def initialize(backend, run, state_dir)
            @backend = backend
            @run = run
            @state_dir = state_dir
            @accepted = false
            @retries = 3
          end

          def handle(job)
            Puppet::FileSystem.mkpath(@state_dir)

            @state_lock ||= Puppet::Util::Pidlock.new(File.join(@state_dir, 'state'))
            unless @state_lock.lock
              # Running concurrently with another process.
              job.disable
              return
            end

            begin
              sched = Schedule.from_scheduler_job(job)
              stamp_file = File.join(@state_dir, 'stamp')

              # If there's a stamp file, we know that this node should be
              # working on this run. If the stamp is newer than our run, another
              # job on this same node processed it first.
              begin
                @accepted ||= Puppet::FileSystem.stat(stamp_file).mtime <= @run.state.updated_at
              rescue Errno::ENOENT # rubocop:disable Lint/HandleExceptions
              end

              # NB: There is a (minor) race condition here where the process
              # could exit (SIGKILL or hard crash) between when the run is
              # accepted by the API and when the acceptance state file is
              # written out. We should update the API to take a unique token
              # that we generate to make acceptance idempotent.
              @accepted ||= @backend.relay_api.post_accept_run(@run)
              if @accepted
                Puppet::FileSystem.touch(stamp_file, mtime: @run.state.updated_at)
              else
                Puppet.notice(_('Run %{id} is already being processed by another job, ignoring') % { id: @run.id })
                job.disable
                return
              end

              if @run.state.status == :pending
                Puppet.notice(_('Run %{id} started') % { id: @run.id })
              end

              begin
                @run = @backend.exec(@run, @state_dir, sched)
              rescue NotImplementedError => e
                message = _('The backend %{backend_name} does not support the configuration for run %{id}: %{message}') % {
                  backend_name: @backend.class.name,
                  id: @run.id,
                  message: e.message,
                }
                Puppet.log_exception(e, message)
                @run = @run.with_state(@run.state.to_complete(outcome: 'error', run_results: { result: { msg: message } }))
              rescue StandardError => e
                message = _('Run %{id} encountered an error during execution: %{message} (%{retries} retries remaining)') % { id: @run.id, message: e.message, retries: @retries }
                Puppet.log_exception(e, message)

                if (@retries -= 1) < 0
                  Puppet.warning(_('Retries exhausted for run %{id}, transitioning to complete with error outcome') % { id: @run.id })
                  @run = @run.with_state(@run.state.to_complete(outcome: 'error', run_results: { result: { msg: message } }))
                end
              ensure
                @run = @backend.relay_api.put_run_state(@run)
                Puppet::FileSystem.touch(stamp_file, mtime: @run.state.updated_at)
              end

              if @run.state.status == :complete
                Puppet.notice(_('Run %{id} completed with outcome %{outcome}') % { id: @run.id, outcome: @run.state.outcome || _('(unknown)') })
                job.disable
              end
            ensure
              @state_lock.unlock

              # If we're finished, we can remove the state directory entirely.
              FileUtils.remove_entry_secure(@state_dir, true) unless job.enabled?
            end
          end
        end
      end
    end
  end
end
