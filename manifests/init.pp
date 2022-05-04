# Configures the Relay report processor and agent.
class relay (
  String $backend,
  Hash[String, Variant[Data, Sensitive[Data]]] $backend_options,
  String $puppet_service,
  String $puppet_user,
  String $puppet_group,
  Optional[Boolean] $debug = undef,
  Optional[Boolean] $test = undef,
  Optional[Stdlib::HTTPUrl] $relay_api_url = undef,
  Optional[Sensitive[String]] $relay_connection_token = undef,
  Optional[Variant[Sensitive[Array[String]], Sensitive[String]]] $relay_trigger_token = undef,
  Optional[String] $proxy_host = undef,
  Optional[Integer] $proxy_port = undef,
  Optional[String] $proxy_user = undef,
  Optional[Sensitive[String]] $proxy_password = undef,
) {
  $settings_file = "${settings::confdir}/relay.yaml"
  $state_file = "${settings::statedir}/relay.json"

  $current_metadata = load_module_metadata($module_name)
  $current_version = $current_metadata['version']

  contain relay::install
  contain relay::service

  Class['::relay::install']
  -> Class['::relay::service']
}
