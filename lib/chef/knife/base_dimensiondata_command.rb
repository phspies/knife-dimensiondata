#
# Author:: Phillip Spies (<phillip.spies@dimensiondata.com>)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'dimensiondata'

# Base class for dimensiondata knife commands
class Chef
  class Knife
    class BaseDimensiondataCommand < Knife

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
               :description => "The username for cloud api"

        option :dimensiondata_pass,
               :short => "-p PASSWORD",
               :long => "--ddpass PASSWORD",
               :description => "The password for cloud api"

        option :dimensiondata_url,
               :short => "-u URL",
               :long => "--ddurl URL",
               :description => "The dimension data cloud geo url"
      end

      def get_dimensiondata_connection
        caas = DimensionData::Client.new(config[:dimensiondata_url], config[:dimensiondata_user], config[:dimensiondata_pass])
        return caas
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
