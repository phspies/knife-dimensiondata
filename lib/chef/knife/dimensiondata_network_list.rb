#
# Author:: Phillip Spies (<phillip.spies@dimensiondata.com>)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'chef/knife/base_dimensiondata_command'

# list networks in datacenter
class Chef::Knife::DimensiondataNetworkList < Chef::Knife::BaseDimensiondataCommand

  banner "knife dimensiondata network list (options)"

  get_common_options
  option :dc,
         :short => "-dc DC",
         :long => "--datacenter DC",
         :description => "Datacenter to list all networks"

  def run
    caas = get_dimensiondata_connection
    if :dc
      if config[:dc].nil?
        show_usage
        fatal_exit("You must specify a datacenter")
      end
      @networks = caas.network.list_in_location(config[:dc])
    else
      @networks = caas.network.list
    end

    case @networks
      when Array
        @networks.each do | network |
          puts "#{ui.color("NETWORK", :cyan)}: #{ui.color("#{network.id}", :red)} - #{network.name}"
        end
      when Hash
        network = @networks
        puts "#{ui.color("NETWORK", :cyan)}: #{ui.color("#{network.id}", :red)} - #{network.name}"
    end


  end
end
