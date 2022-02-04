require 'json'
require 'puppet'

require_relative '../../util/http'
require_relative '../model'
require_relative '../job/schedule'
require_relative 'base'

module PuppetX
  module Relay
    module Agent
      module Backend
        class Orchestrator < Base
          # @param orchestrator_api [Util::HTTP::Client]
          def initialize(relay_api, orchestrator_api)
            super(relay_api)
            @orchestrator_api = orchestrator_api
          end

          def exec(run, _state_dir, schedule)
            case run.state.status
            when :pending
              case run
              when Model::Run
                deploy(run, schedule)
              when Model::TaskRun
                task(run, schedule)
              when Model::PlanRun
                plan_run(run, schedule)
              else
                raise NotImplementedError
              end
            else
              check_complete(run, schedule)
            end
          rescue Net::HTTPError, Net::HTTPRetriableError, Net::HTTPServerException, Net::HTTPFatalError => e
            Puppet.warning(_('Failed to send request to orchestrator API: %{message}, response: %{body}') % {
              message: e.message,
              body: e.response.body,
            })
            raise
          end

          private

          # @param run [Model::Run]
          # @param schedule [Job::Schedule]
          def deploy(run, schedule)
            payload = {
              environment: run.environment,
              scope: run.scope,
              debug: run.debug,
              trace: run.trace,
              evaltrace: run.evaltrace,
            }
            run.noop ? payload[:noop] = true : payload[:no_noop] = true
            resp = @orchestrator_api.post(
              'command/deploy',
              body: payload,
            )
            resp.value

            data = JSON.parse(resp.body)

            Puppet.info(_('Orchestrator job %{job_id} started for run %{id}') % { job_id: data['job']['name'], id: run.id })

            new_state = run.state.to_in_progress(schedule.next_update_before, job_id: data['job']['name'])
            run.with_state(new_state)
          end

          # @param run [Model::TaskRun]
          # @param schedule [Job::Schedule]
          def task(run, schedule)
            resp = @orchestrator_api.post(
              'command/task',
              body: {
                environment: run.environment,
                scope: run.scope,
                task: run.name,
                params: run.params,
                noop: run.noop,
                targets: run.targets,
              },
            )
            resp.value

            data = JSON.parse(resp.body)

            Puppet.info(_('Orchestrator job %{job_id} started for task run %{id}') % { job_id: data['job']['name'], id: run.id })

            new_state = run.state.to_in_progress(schedule.next_update_before, job_id: data['job']['name'])
            run.with_state(new_state)
          end

          # @param run [Model::PlanRun]
          # @param schedule [Job::Schedule]
          def plan_run(run, schedule)
            resp = @orchestrator_api.post(
              'command/plan_run',
              body: {
                environment: run.environment,
                plan_name: run.name,
                params: run.params,
              },
            )
            resp.value

            data = JSON.parse(resp.body)

            Puppet.info(_('Orchestrator job %{job_id} started for plan run %{id}') % { job_id: data['name'], id: run.id })

            new_state = run.state.to_in_progress(schedule.next_update_before, job_id: data['name'])
            run.with_state(new_state)
          end

          # @param run [Model::Stateful]
          # @param schedule [Job::Schedule]
          def check_complete(run, schedule)
            run_type = run.class.name.split('::').last
            Puppet.debug("Checking completion of run: #{run} of type #{run_type}")
            uri = "jobs/#{run.state.job_id}"
            uri = "plan_jobs/#{run.state.job_id}" if run_type == 'PlanRun'
            resp = @orchestrator_api.get(uri)
            resp.value

            data = JSON.parse(resp.body)

            new_state =
              case data['state']
              when 'finished', 'failed', 'success'
                if run_type == 'TaskRun'
                  resp = @orchestrator_api.get("jobs/#{run.state.job_id}/nodes")
                  resp_json = JSON.parse(resp.body)
                  run_results = resp_json['items']
                else
                  run_results = data
                end
                Puppet.debug("Run results: #{run_results}")
                run.state.to_complete(outcome: data['state'], run_results: run_results)
              else
                run.state.to_in_progress(schedule.next_update_before)
              end

            run.with_state(new_state)
          end
        end
      end
    end
  end
end
