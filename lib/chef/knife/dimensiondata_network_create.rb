#
# Author:: Phillip Spies (<phillip.spies@dimensiondata.com>)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'chef/knife/base_dimensiondata_command'

# list networks in datacenter
class Chef::Knife::DimensionDataNetworkList < Chef::Knife::BaseDimensionDataCommand
  banner "knife dimensiondata network create (options)"

  get_common_options
  option :network,
         :long => "--network NetworkName",
         :description => "Name to be used by network"

  option :description,
         :long => "--description Description",
         :description => "Description to be used by network"

  option :dc,
         :long => "--datacenter DC",
         :description => "Datacenter where server should be created"

  def run
    if (config[:network].nil? || config[:dc].nil?)
      show_usage
      fatal_exit("You must specify both network and datacenter")
    end

    mcp.network.create(config[:network], config[:dc], config[:description])

  end
end
