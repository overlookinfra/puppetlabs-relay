# Changelog

All notable changes to this project will be documented in this file.

## Release 2.3.1

Fixed: Relay API client changes in previous release made it incompatible with the Report Processor. This is now fixed.

## Release 2.3.0

Added: Proxy support for Relay Agent.

## Release 2.2.0

Added: The Puppet Enterprise orchestrator backend now supports dispatching tasks and plans.

## Release 2.1.5

Releases v2.1.2, v2.1.3, and v2.1.4 are skipped.

Fixed: Rubocop and testing tweaks
Fixed: Updated HEAD's branch name

## Release 2.1.1

Changed no-op logic to match orchestrator API's rules for overriding hardcoded
noop=true via no\_noop flag; docs updates.

## Release 2.1.0

Added: Reports now include whether a resource had a corrective change and its containment path.

## Release 2.0.0

Added: Support for bidirectional communication with the Relay SaaS using an
agent.

Changed: The Puppet class was adjusted to better support both the SaaS agent and the report processor.

## Release 1.2.0

Added: Foss puppetserver support.

Fixed: Pluginsync pathing

## Release 1.1.0

Added: The `facts` trigger payload value.

## Release 1.0.1

Fixed: Added dependency in metadata

## Release 1.0.0

Initial release. Includes a report processor that submits run status and log
messages for each puppet run.
