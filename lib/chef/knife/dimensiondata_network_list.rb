#
# Author:: Phillip Spies (<phillip.spies@dimensiondata.com>)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'chef/knife/base_dimensiondata_command'

# list networks in datacenter
class Chef::Knife::DimensionDataNetworkList < Chef::Knife::BaseDimensionDataCommand
  banner "knife dimensiondata network list (options)"

  get_common_options

  option :dc,
         :short => "-dc DC",
         :long => "--datacenter DC",
         :description => "Datacenter to list all networks"

  def run
    $stdout.sync = true
    if :dc
      if config[:dc].nil?
        show_usage
        fatal_exit("You must specify a datacenter")
      end
      @networks = mcp.network.list_in_location(config[:dc])
    else
      @networks = mcp.network.list
    end

    @network.each do | network |
      puts "#{ui.color("NETWORK", :cyan)}: #{network.id} - #{network.name} - #{network.description} "
    end


  end
end
