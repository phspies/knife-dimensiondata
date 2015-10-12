#
# Author:: Phillip Spies (<phillip.spies@dimensiondata.com>)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'chef/knife/base_dimensiondata_command'
require 'netaddr'
require 'sambal'
require 'chef/knife/winrm_base'
require 'winrm'
require 'em-winrm'
require 'chef/knife/winrm'
require 'chef/knife/bootstrap_windows_winrm'
require 'chef/knife/bootstrap_windows_ssh'
require 'chef/knife/core/windows_bootstrap_context'

# list networks in datacenter
class Chef::Knife::DimensiondataWorkloadCreate < Chef::Knife::BaseDimensiondataCommand

  banner "knife dimensiondata workload create (options)"

  get_common_options

  option :vm_name,
         :long => "--workload_hostname name",
         :description => "Workload name to use during deployment"
  option :template_id,
         :long => "--template_id template",
         :description => "Template that should be used in this deployment"
  option :domain_id,
         :long => "--network_domain domain_id",
         :description => "Network domain in which this workload should be created"
  option :vlan_id,
         :long => "--network_vlan vlan_id",
         :description => "Network vlan in which this workload should be created"
  option :password,
         :long => "--password password",
         :description => "Password to set the Administrator user"
  option :dnsservers,
         :long => "--dnsservers dnsservers",
         :description => "DNS servers to populate during deployment"
  option :dnsdomain,
         :long => "--dnsdomain dnsdomain",
         :description => "DNS domain name to populate during deployment"

  def run
    caas = get_dimensiondata_connection
    if (config[:vm_name].nil?)
      show_usage
      fatal_exit("You must specify workload hostname")
    end
    if (config[:template_id].nil?)
      show_usage
      fatal_exit("You must specify template")
    end
    if (config[:domain_id].nil?)
      show_usage
      fatal_exit("You must specify network domains id")
    end
    if (config[:vlan_id].nil?)
      show_usage
      fatal_exit("You must specify network vlan id")
    end
    if (config[:password].nil?)
      show_usage
      fatal_exit("You must specify administrator/root password")
    end
    if (config[:dnsservers].nil?)
      show_usage
      fatal_exit("You must specify dnsservers")
    end
    if (config[:dnsdomain].nil?)
      show_usage
      fatal_exit("You must specify dnsdomain")
    end
    network_domain = caas.network2.get_domain(config[:domain_id])
    network_vlan = caas.network2.get_vlan(config[:vlan_id])
    puts "Creating workload #{config[:vm_name]} in #{network_domain.name} network domain and #{network_vlan.name} vlan"

    result = caas.server2.create_with_vlan(config[:vm_name], "",config[:domain_id], config[:vlan_id], config[:template_id], config[:password], true)
    puts "Created workload #{result.info.value}"

    workload = caas.server2.show(result.info.value)

    wait_for_deploy(workload, caas, 300, 10)

    connect_host = workload.network_info.primary_nic.ipv6

    Chef::Log.debug("Upload OS customization code: #{connect_host}")
    case (workload.operating_system.family)
      when "WINDOWS"
        client = Sambal::Client.new(domain: 'WORKGROUP', host: "#{connect_host}", share: 'C$', user: 'Administrator', password: "#{config[:password]}", port: 445)
        client.put(config[:windows_customization],"c:\oscustomization.exe")
        `winexe -user Administrator -password "#{config[:password]}" //host ${connect_host} winrm quickconfig`
        `winexe -user Administrator -password "#{config[:password]}" //host ${connect_host} winrm set winrm/config/service/auth @{Basic="true"}`
        `winexe -user Administrator -password "#{config[:password]}" //host ${connect_host} winrm set winrm/config/service @{AllowUnencrypted="true"}`
        `winexe -user Administrator -password "#{config[:password]}" //host ${connect_host} "c:\oscustomization.exe /hostname:#{config[:hostname]} /dnsservers:#{config[:dnsservers]} /dnsdomain:#{config[:dnsdomain]} /reboot+"`
      when "LINUX"
        `sshpass -p '#{config[:password]}' scp #{config[:linux_customization]} root@#{connect_host}:/tmp`
        `sshpass -p '#{config[:password]}' ssh root@#{connect_host} /tmp/oscustomization.sh #{config[:hostname]} #{config[:dnsservers]} #{config[:dnsdomain]}`
        `sshpass -p '#{config[:password]}' ssh root@#{connect_host} reboot`
    end
    sleep(10)
    wait_for_deploy(workload, caas, 1800, 10)

    Chef::Log.debug("Connect Host for Bootstrap: #{connect_host}")
    connect_port = get_config(:ssh_port)
    protocol = get_config(:bootstrap_protocol)
    case (workload.operating_system.family)
      when "WINDOWS"
        protocol ||= 'winrm'
        # Set distro to windows-chef-client-msi
        config[:distro] = 'windows-chef-client-msi' if config[:distro].nil? || config[:distro] == 'chef-full'
        wait_for_access(connect_host, connect_port, protocol)
        ssh_override_winrm
        bootstrap_for_windows_node.run
      when "LINUX"
        protocol ||= 'ssh'
        wait_for_access(connect_host, connect_port, protocol)
        ssh_override_winrm
        bootstrap_for_node.run
    end
  end

  def wait_for_deploy(workload, caas_connection, timeout, sleep_time)

    wait = true
    waited_seconds = 0

    print 'Waiting for workload to deploy...'
    while wait

      @workload = caas_connection.server2.show(workload.id)
      if @workload.state == "NORMAL"
        wait = false
      elsif waited_seconds >= timeout
        abort "\nDeployment of VM #{workload.name} not succeeded within #{timeout} seconds."
      else
        print '.'
        sleep(sleep_time)
        waited_seconds += sleep_time
      end
    end
  end
  def wait_for_access(connect_host, connect_port, protocol)
    if protocol == 'winrm'
      load_winrm_deps
      if get_config(:winrm_transport) == 'ssl' && get_config(:winrm_port) == '5985'
        config[:winrm_port] = '5986'
      end
      connect_port = get_config(:winrm_port)
      print "\n#{ui.color("Waiting for winrm access to become available on #{connect_host}:#{connect_port}",:magenta)}"
      print('.') until tcp_test_winrm(connect_host, connect_port) do
        sleep 10
        puts('done')
      end
    else
      print "\n#{ui.color("Waiting for sshd access to become available on #{connect_host}:#{connect_port}", :magenta)}"
      print('.') until tcp_test_ssh(connect_host, connect_port) do
        sleep 10
        puts('done')
      end
    end
    connect_port
  end
  def bootstrap_common_params(bootstrap)
    bootstrap.config[:run_list] = config[:run_list]
    bootstrap.config[:bootstrap_version] = get_config(:bootstrap_version)
    bootstrap.config[:distro] = get_config(:distro)
    bootstrap.config[:template_file] = get_config(:template_file)
    bootstrap.config[:environment] = get_config(:environment)
    bootstrap.config[:prerelease] = get_config(:prerelease)
    bootstrap.config[:first_boot_attributes] = get_config(:first_boot_attributes)
    bootstrap.config[:hint] = get_config(:hint)
    bootstrap.config[:chef_node_name] = get_config(:chef_node_name)
    bootstrap.config[:bootstrap_vault_file] = get_config(:bootstrap_vault_file)
    bootstrap.config[:bootstrap_vault_json] = get_config(:bootstrap_vault_json)
    bootstrap.config[:bootstrap_vault_item] = get_config(:bootstrap_vault_item)
    # may be needed for vpc mode
    bootstrap.config[:no_host_key_verify] = get_config(:no_host_key_verify)
    bootstrap
  end

  def bootstrap_for_windows_node
    Chef::Knife::Bootstrap.load_deps
    if get_config(:bootstrap_protocol) == 'winrm' || get_config(:bootstrap_protocol).nil?
      bootstrap = Chef::Knife::BootstrapWindowsWinrm.new
      bootstrap.name_args = [config[:fqdn]]
      bootstrap.config[:winrm_user] = get_config(:winrm_user)
      bootstrap.config[:winrm_password] = get_config(:winrm_password)
      bootstrap.config[:winrm_transport] = get_config(:winrm_transport)
      bootstrap.config[:winrm_port] = get_config(:winrm_port)
    elsif get_config(:bootstrap_protocol) == 'ssh'
      bootstrap = Chef::Knife::BootstrapWindowsSsh.new
      bootstrap.config[:ssh_user] = get_config(:ssh_user)
      bootstrap.config[:ssh_password] = get_config(:ssh_password)
      bootstrap.config[:ssh_port] = get_config(:ssh_port)
    else
      ui.error('Unsupported Bootstrapping Protocol. Supports : winrm, ssh')
      exit 1
    end
    bootstrap_common_params(bootstrap)
  end

  def bootstrap_for_node
    Chef::Knife::Bootstrap.load_deps
    bootstrap = Chef::Knife::Bootstrap.new
    bootstrap.name_args = [config[:fqdn]]
    bootstrap.config[:secret_file] = get_config(:secret_file)
    bootstrap.config[:ssh_user] = get_config(:ssh_user)
    bootstrap.config[:ssh_password] = get_config(:ssh_password)
    bootstrap.config[:ssh_port] = get_config(:ssh_port)
    bootstrap.config[:identity_file] = get_config(:identity_file)
    bootstrap.config[:use_sudo] = true unless get_config(:ssh_user) == 'root'
    bootstrap.config[:log_level] = get_config(:log_level)
    bootstrap_common_params(bootstrap)
  end

  def ssh_override_winrm
    # unchanged ssh_user and changed winrm_user, override ssh_user
    if get_config(:ssh_user).eql?(options[:ssh_user][:default]) &&
        !get_config(:winrm_user).eql?(options[:winrm_user][:default])
      config[:ssh_user] = get_config(:winrm_user)
    end

    # unchanged ssh_port and changed winrm_port, override ssh_port
    if get_config(:ssh_port).eql?(options[:ssh_port][:default]) &&
        !get_config(:winrm_port).eql?(options[:winrm_port][:default])
      config[:ssh_port] = get_config(:winrm_port)
    end

    # unset ssh_password and set winrm_password, override ssh_password
    if get_config(:ssh_password).nil? &&
        !get_config(:winrm_password).nil?
      config[:ssh_password] = get_config(:winrm_password)
    end

    # unset identity_file and set kerberos_keytab_file, override identity_file
    return unless get_config(:identity_file).nil? && !get_config(:kerberos_keytab_file).nil?

    config[:identity_file] = get_config(:kerberos_keytab_file)
  end

  def tcp_test_ssh(hostname, ssh_port)
    tcp_socket = TCPSocket.new(hostname, ssh_port)
    readable = IO.select([tcp_socket], nil, nil, 5)
    if readable
      ssh_banner = tcp_socket.gets
      if ssh_banner.nil? || ssh_banner.empty?
        false
      else
        Chef::Log.debug("sshd accepting connections on #{hostname}, banner is #{ssh_banner}")
        yield
        true
      end
    else
      false
    end
  rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, IOError
    Chef::Log.debug("ssh failed to connect: #{hostname}")
    sleep 2
    false
  rescue Errno::EPERM, Errno::ETIMEDOUT
    Chef::Log.debug("ssh timed out: #{hostname}")
    false
  rescue Errno::ECONNRESET
    Chef::Log.debug("ssh reset its connection: #{hostname}")
    sleep 2
    false
  ensure
    tcp_socket && tcp_socket.close
  end

  def tcp_test_winrm(hostname, port)
    tcp_socket = TCPSocket.new(hostname, port)
    yield
    true
  rescue SocketError
    sleep 2
    false
  rescue Errno::ETIMEDOUT
    false
  rescue Errno::EPERM
    false
  rescue Errno::ECONNREFUSED
    sleep 2
    false
  rescue Errno::EHOSTUNREACH
    sleep 2
    false
  rescue Errno::ENETUNREACH
    sleep 2
    false
  ensure
    tcp_socket && tcp_socket.close
  end

end
