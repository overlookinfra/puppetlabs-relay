# relay

## Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with relay](#setup)
    * [What relay affects](#what-relay-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with relay](#beginning-with-relay)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

This module configures a report processor to submit any changed resources to
the Relay SaaS event trigger API. Workflows may subscribe to the triggers and
decide whether to run based on the run status and log lines.

Second, it runs a Relay agent on your puppetserver which can be used to trigger
puppet runs on specific nodes, without requiring inbound connectivity from
Relay to your puppetserver.

## Setup

### Requirements

You must already have a puppetserver to which puppet agents submit reports and
that can connect to the internet. Because you'll need to store access tokens
for Relay, we strongly recommend using eyaml to encrypt the tokens as hiera keys.

You must also have a Relay account registered. You can sign up for free at
[https://relay.sh/](https://relay.sh/) if you do not already have an account.

### Set up Relay

The report processor needs a Relay [push-trigger access token](https://relay.sh/docs/reference/relay-workflows/#push) that is
authorized to talk to the Relay API. To generate an access token, add a workflow
push trigger to a Relay workflow and copy the token from the sidebar.

The workflow trigger in Relay will look like this:

```yaml
triggers:
  - name: puppet-report
    source:
      type: push
    binding:
      parameters:
        host: !Data host
        resource_statuses: !Data resource_statuses
        status: !Data status
        time: !Data time
```

You'll then copy the access token from the Triggers section of the workflow page:
![ Copying access token from the workflow page](https://github.com/puppetlabs/puppetlabs-relay/raw/main/media/push-trigger.png)

To see an example of a Relay workflow that uses this trigger, see
[the puppet-shutdown-ec2 example workflow](https://github.com/puppetlabs/relay-workflows/tree/master/puppet-shutdown-ec2), which watches for unexpected changes to the `sudoers` file
and shuts down affected nodes for investigation.

To use the Relay agent capability, which enables you to trigger
Puppet runs from Relay workflows, you'll also need to set up a
Puppet connection in the Relay app. This will generate a separate
token that the Relay agent, running on your puppetserver, uses to
authenticate run requests from the service. To configure this, go
to the **Connections** screen and click **Add connection**. Select
the **Puppet** connection type from the drop-down menu, give it a
name, and save the resulting token - it won't be displayed again.

![Adding a new Puppet connection in Relay](https://github.com/puppetlabs/puppetlabs-relay/raw/main/media/new-connection.png)

### 2. Configure the puppetserver

The report processor may be automatically set up by classifying the puppetserver
host with the `relay` class. This class will:

1. configure the report processor setting on the puppetserver to include the
   `relay` report processor if you specify one or more trigger tokens
1. (on Puppet Enterprise) reload the puppetserver process to load the new report
   processor
1. configure the agent to synchronize with the Relay service if you specify a
   connection token
1. set up the Relay agent configuration and service to run automatically

For Puppet Enterprise, add the `relay` class to the Node Classifier group
that contains your puppetmasters. Open source Puppet classification will
vary per local setup, but you'll need to make sure the hosts running
puppetservers also are classified with the `relay` class.

We recommend using hiera to store the configuration for the Relay module,
and specifically to use hiera-eyaml to prevent hardcoding the tokens in
your configuration. For more information on hiera-eyaml, see the [hiera-eyaml documentation on Github](https://github.com/voxpupuli/hiera-eyaml). You'll need to hiera keys with the eyaml-encrypted values of the Relay push token at a minimum.
Additionally, if you're using the Relay agent functionality, add the token for
the Puppet connection and either the PE Orchestrator access token or
a ssh key to enable Bolt to access nodes.

```yaml
# this token is from the "trigger" configuration
relay::relay_trigger_token: >
    ENC[PKCS7,.....]
# this token is from the Puppet connection setup
relay::relay_connection_token: >
    ENC[PKCS7,.....]
# For PE, this token is from `puppet access show`
relay::backend_options:
  token: >
    ENC[PKCS7,.....]
# For ssh access to nodes, configure ssh backend options instead
relay::backend: ssh
relay::backend_options:
  host_key_check: false,
  user: puppet-automation
  password: >
    ENC[PKCS7,.....]
```


## Example #1: Trigger Relay workflow from Puppet run

Run the Puppet agent (either in noop or enforce mode) to trigger a Relay workflow.

If the Relay report processor detects an out-of-sync resource, with the agent
in either no-op or enforce mode, it will send the report details to the Relay
push API, authenticated with the `relay_trigger_token` we configured above.
The workflow can then take action using any combination the steps from the
[Relay integration library](https://relay.sh/library/).

The example [puppet-shutdown-ec2](https://github.com/puppetlabs/relay-workflows/tree/master/puppet-shutdown-ec2) module looks for unexpected changes in sudoers and
fences off potentially compromised nodes by shutting them down.

## Example #2: Trigger Puppet run from Relay

To connect Relay workflows to your Puppet estate, configure the
Puppet connection in Relay as described above. Make sure the relay
agent is running on your puppetserver node; this agent makes outbound
connections to periodically poll the Relay service for new actions
to take, and will then use the transport configured in `backend_options`
parameters to kick off Puppet agent runs on the nodes the workflow
specifies.

To set this up, add a Puppet connection in Relay, then add a step like
the following to your Relay workflow. Make sure the `name` field in the
`!Connection` value matches the name you set at creation time. In this
example, the workflow has a parameter `host` which the user supplies;
instead of `!Parameter host`, you could use the [output of an earlier step](https://relay.sh/docs/using-workflows/passing-data-into-workflow-steps/) or
[data fields from a push or webhook trigger](https://relay.sh/docs/using-workflows/using-triggers/#push-triggers).

```yaml
parameters:
  host:
    description: Which host to kick off a puppet agent run
steps:
- name: start-puppet-run
  image: relaysh/puppet-step-run-start
  spec:
    connection: !Connection { type: puppet, name: my-puppet-server }
    environment: production
    scope:
      nodes:
      - !Parameter host
```

When your Relay workflow runs, it will start a puppet run on the target host.

## Reference

### `relay` class

This is class used to configure the report processor and agent.

#### Parameters

##### `debug`

Type: Boolean

Whether to enable debug logging for the report processor and agent.

Default: `false`

##### `test`

Type: Boolean

Whether to enable test mode and verbosity for the report processor and agent.

Default: `false`

##### `relay_api_url`

Type: String

The base URL to the Relay API to connect to.

Default: `"https://api.relay.sh"`

##### `relay_connection_token`

Type: Sensitive[String]

The connection token to use for the agent. If not specified, the agent is
disabled.

##### `relay_trigger_token`

Type: Sensitive[String] or Array[Sensitive[String]]

One or more trigger tokens to use to start Relay workflows from the report
processor. If not defined or an empty array, the report processor is disabled.

##### `backend`

Type: String

The backend to use for running the Puppet agent.

Options:
- `"orchestrator"`
- `"bolt"`
- `"ssh"` (coming soon!)

Default: `"orchestrator"` in Puppet Enterprise, `"bolt"` otherwise.

##### `backend_options`

Type: Hash[String, Variant[Data, Sensitive[Data]]]

A hash of options to configure the given backend. The options available differ
depending on which backend is chosen.

For backend `"orchestrator"`:

* `api_url`: The URL to the orchestrator API. Make sure to include the trailing
  slash in the URL. Default: `"https://{puppetserver}:8143/orchestrator/v1/"`
* `token`: The RBAC token to use to access the orchestrator API. Sensitive.
  **Required.**

For backend `"bolt"`:

* `bolt_command`: The path to the Bolt command as an array. Default: `["bolt"]`
* `ssh_user`: The username to use to connect to the node to run Puppet on.
  Default: `"root"`
* `ssh_password`: The password to use to connect to the node to run Puppet on.
  Sensitive.
* `ssh_host_key_check`: Whether to enable host key checking for the target node.
  Default: `true`

##### `puppet_service`

Type: String

The name of the Puppet service.

Default: `"pe-puppetserver"` in Puppet Enterprise, `"puppetserver"` otherwise.

##### `puppet_user`

Type: String

The user the Puppet service and Relay agent run under.

Default: `"pe-puppet"` in Puppet Enterprise, `"puppet"` otherwise.

##### `puppet_group`

Type: String

The group the Puppet service and Relay agent run under.

Default: `"pe-puppet"` in Puppet Enterprise, `"puppet"` otherwise.

##### `proxy_host`

Type: String

The proxy hostname or IP address. The Relay agent will use this proxy to connect to Relay.

##### `proxy_port`

Type: Integer

The proxy port to connect to on the `proxy_host`.

##### `proxy_user`

Type: String

The user for authenticating to the proxy. Do not specify this parameter if the proxy does not require authentication.

##### `proxy_password`

Type: Sensitive[String]

The password for authenticating to the proxy. Do not specify this parameter if the proxy does not require authentication.


### Report processor event

Every relay trigger event payload includes several fields from the report. The
field are derived from the Puppet report object as detailed in [the official
documentation](https://puppet.com/docs/puppet/6.17/format_report.html).

#### Fields

##### `host`

The hostname that submitted the report.

##### `noop`

True if the agent was run in no-op mode, false if the agent was run in enforce
mode.

##### `status`

This is the run status (`"changed"`, etc.). Useful for detecting failures.

##### `time`

The timestamp of when the puppet run began in ISO 8601 format.

##### `configuration_version`

The version of the catalog applied to the node.

##### `transaction_uuid`

The unique identifier for the catalog run.

##### `code_id`

The code ID for the static file content server.

##### `summary`

This is the long-form summary of the puppet run. It is more useful from a human
perspective but may be inspected programmatically for puppet run information.

##### `resource_statuses`

For each resource that changed or was out of sync when the run occurred, a map of the resource name to an object containing:

* `resource_type`: The type of the resource, such as `File`
* `title`: The title of the resource, such as `/tmp/test`
* `change_count`: The number of property changes to the resource
* `out_of_sync_count`: The number of properties that were out of sync on the
  node
* `containment_path`: The full hierarchical path to the resource
* `corrective_change`: True if this change reflected a correction of
  configuration drift, false otherwise

## Limitations

The report processor submits a subset of the full report. Full report submission
will come soon, as they need to be compressed before transmission.
