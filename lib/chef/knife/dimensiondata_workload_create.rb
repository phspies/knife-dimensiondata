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
  option :windows_customization,
         :long => "--windows_customization file",
         :description => "Windows customization script"
  option :linux_customization,
         :long => "--linux_customization file",
         :description => "Linux customization script"
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

    wait_for_deploy(workload, caas, 1800, 10)

    connect_host = workload.network_info.primary_nic.ipv6

    print "\n#{ui.color("Uploading OS customization code to #{connect_host}")}\n"
    print "\n#{ui.color("Host Preperation Type: #{workload.operating_system.family}")}\n"
    case (workload.operating_system.family)
      when "WINDOWS"
        client = Sambal::Client.new(domain: 'WORKGROUP', host: "#{connect_host}", share: 'C$', user: 'Administrator', password: "#{config[:password]}", port: 445)
        client.put(config[:windows_customization],"c:\oscustomization.exe")
        winrm = WinRM::WinRMWebService.new("http://[#{connect_host}]:5985/wsman", :plaintext, :user => "Administrator", :pass => "#{config[:password]}", :basic_auth_only => true)
        winrm.cmd("c:\oscustomization.exe /hostname:#{config[:vm_name]} /dnsservers:#{config[:dnsservers]} /dnsdomain:#{config[:dnsdomain]} /reboot+")
        sleep(30)
        wait_for_access(connect_host, 5986, 'winrm')
      when "UNIX"
        `ssh-keyscan -H #{connect_host} >> ~/.ssh/known_hosts`

        print "\n#{ui.color("Host Preperation Type: #{workload.operating_system.family}")}"

        `sshpass -p "#{config[:password]}" scp -6 #{config[:linux_customization]} root@\[#{connect_host}\]:/tmp`

        case (workload.operating_system.id)
          when /REDHAT/
          when /CENTOS/
            `sshpass -p "#{config[:password]}" ssh root@#{connect_host} yum install wget`
          when /UBUNTU/
            `sshpass -p "#{config[:password]}" ssh root@#{connect_host} apt-get install wget`
          when /SUSE/

        end

        `sshpass -p "#{config[:password]}" ssh root@#{connect_host} /tmp/oscustomization.sh #{config[:vm_name]} #{config[:dnsservers]} #{config[:dnsdomain]}`
        `sshpass -p "#{config[:password]}" ssh root@#{connect_host} reboot`
        sleep(10)
        wait_for_access(connect_host, 22, 'ssh')
    end
    print "\n#{ui.color("Connect Host for Bootstrap: #{connect_host} #{workload.operating_system.family}")}\n"
    case (workload.operating_system.family)
      when "WINDOWS"
        config[:distro] = 'windows-chef-client-msi' if config[:distro].nil? || config[:distro] == 'chef-full'
        bootstrap_for_windows_node(config[:vm_name], connect_host)
      when "UNIX"
        bootstrap_for_linux_node(config[:vm_name],connect_host)
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
      print "\n#{ui.color("Waiting for winrm access to become available on #{connect_host}:#{connect_port}",:magenta)}\n"
      print('.') until tcp_test_winrm(connect_host, connect_port) do
        sleep 10
        puts('done')
      end
    else
      print "\n#{ui.color("Waiting for sshd access to become available on #{connect_host}:#{connect_port}", :magenta)}\n"
      print('.') until tcp_test_ssh(connect_host, connect_port) do
        sleep 10
        puts('done')
      end
    end
    connect_port
  end
  def load_winrm_deps
    require 'winrm'
    require 'em-winrm'
    require 'chef/knife/bootstrap_windows_winrm'
    require 'chef/knife/core/windows_bootstrap_context'
    require 'chef/knife/winrm'
  end
  def bootstrap_for_windows_node(hostname,ip)
    Chef::Knife::Bootstrap.load_deps
    bootstrap = Chef::Knife::BootstrapWindowsWinrm.new
    bootstrap.name_args = ip
    bootstrap.config[:winrm_user] = 'Administrator'
    bootstrap.config[:chef_node_name] = hostname
    bootstrap.config[:winrm_password] = config[:password]
    bootstrap.config[:winrm_transport] = 'winrm'
    bootstrap.config[:winrm_port] = '5985'
    bootstrap.run

  end

  def bootstrap_for_linux_node(hostname,ip)
    Chef::Knife::Bootstrap.load_deps
    bootstrap = Chef::Knife::Bootstrap.new
    bootstrap.name_args = ip
    bootstrap.config[:ssh_user] = 'root'
    bootstrap.config[:chef_node_name] = hostname
    bootstrap.config[:ssh_password] = config[:password]
    bootstrap.config[:ssh_port] = '22'
    bootstrap.config[:use_sudo] = false
    bootstrap.run
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
