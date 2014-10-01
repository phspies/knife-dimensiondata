#
# Author:: Phillip Spies (<phillip.spies@dimensiondata.com>)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'dimensiondata'

# Base class for dimensiondata knife commands
class Chef
  class Knife
    class BaseDimensionDataCommand < Knife

      deps do
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps
        require 'fog'
        require 'socket'
        require 'net/ssh/multi'
        require 'readline'
        require 'chef/json_compat'
      end

      def self.get_common_options
        unless defined? $default
          $default = Hash.new
        end

        option :dimensiondata_user,
               :short => "-u USERNAME",
               :long => "--dduser USERNAME",
               :description => "The username for vsphere"

        option :dimensiondata_pass,
               :short => "-p PASSWORD",
               :long => "--ddpass PASSWORD",
               :description => "The password for vsphere"

        option :dimensiondata_url,
               :short => "-u URL",
               :long => "--ddurl URL",
               :description => "The dimension data cloud geo url"

        option :dimensiondata_dc,
               :short => "-d DATACENTER",
               :long => "--dddc DATACENTER",
               :description => "The datacenter for dimension data"
      end

      def get_config(key)
        key = key.to_sym
        rval = config[key] || Chef::Config[:knife][key] || $default[key]
        Chef::Log.debug("value for config item #{key}: #{rval}")
        rval
      end

      def get_dimensiondata_connection

        conn_opts = {
            :url => get_config(:dimensiondata_url),
            :user => get_config(:dimensiondata_user),
            :password => get_config(:dimensiondata_pass),
            :dc => get_config(:dimensiondata_dc),
        }

        # Grab the password from the command line
        # if tt is not in the config file
        if not conn_opts[:password]
          conn_opts[:password] = get_password
        end

        caas = DimensionData::Client.new config[:url], config[:user], config[:password], config[:dc]
        config[:caas] = caas
        return mcp


      end

      def get_password
        @password ||= ui.ask("Enter your password: ") { |q| q.echo = false }
      end

      def fatal_exit(msg)
        ui.fatal(msg)
        exit 1
      end

      def tcp_test_port_vm(server, port)
        ip = server.ipAddress
        if ip.nil?
          sleep 2
          return false
        end
        tcp_test_port(ip, port)
      end

      def tcp_test_port(hostname, port)
        tcp_socket = TCPSocket.new(hostname, port)
        readable = IO.select([tcp_socket], nil, nil, 5)
        if readable
          Chef::Log.debug("sshd accepting connections on #{hostname}, banner is #{tcp_socket.gets}") if port == 22
          true
        else
          false
        end
      rescue Errno::ETIMEDOUT
        false
      rescue Errno::EPERM
        false
      rescue Errno::ECONNREFUSED
        sleep 2
        false
      rescue Errno::EHOSTUNREACH, Errno::ENETUNREACH
        sleep 2
        false
      ensure
        tcp_socket && tcp_socket.close
      end

    end
  end
end
