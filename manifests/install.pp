# @api private
class relay::install {
  file { $relay::settings_file:
    ensure  => file,
    owner   => $relay::puppet_user,
    group   => $relay::puppet_group,
    mode    => '0640',
    content => Sensitive(epp('relay/settings.yaml.epp', {
      debug                  => $relay::debug,
      test                   => $relay::test,
      relay_api_url          => $relay::relay_api_url,
      relay_connection_token => $relay::relay_connection_token,
      relay_trigger_token    => $relay::relay_trigger_token,
      backend                => $relay::backend,
      backend_options        => $relay::backend_options,
      proxy_host             => $relay::proxy_host,
      proxy_port             => $relay::proxy_port,
      proxy_user             => $relay::proxy_user,
      proxy_password         => $relay::proxy_password,
    })),
  }

  $agent_enabled = $relay::relay_connection_token ? {
    undef   => false,
    default => true,
  }

  $agent_unit_ensure = $agent_enabled ? { true => present, default => absent }

  file { '/etc/systemd/system/relay-agent.service':
    ensure  => $agent_unit_ensure,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('relay/agent.service.epp', {}),
  }

  $agent_run_dir_ensure = $agent_enabled ? { true => directory, default => absent }

  file { '/var/run/puppetlabs/relay':
    ensure => $agent_run_dir_ensure,
    force  => true,
    owner  => $relay::puppet_user,
    group  => $relay::puppet_group,
    mode   => '0750',
  }

  $report_processor_ensure = $relay::relay_trigger_token ? {
    undef   => absent,
    default => present,
  }

  ini_subsetting { 'puppetserver puppetconf report processor':
    ensure               => $report_processor_ensure,
    path                 => $settings::config,
    section              => 'master',
    setting              => 'reports',
    subsetting           => 'relay',
    subsetting_separator => ',',
    require              => File[$relay::settings_file],
  }

  file { $relay::state_file:
    ensure  => file,
    owner   => $relay::puppet_user,
    group   => $relay::puppet_group,
    mode    => '0640',
    content => to_json_pretty({
      version                  => $relay::current_version,
      report_processor_enabled => $report_processor_ensure == present,
    }),
  }

  if $facts['puppet_type'] == 'enterprise' {
    File[$relay::state_file] ~> Service[$relay::puppet_service]
  }
}
