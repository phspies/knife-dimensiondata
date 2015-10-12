#
# Author:: Phillip Spies (<phillip.spies@dimensiondata.com>)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'chef/knife/base_dimensiondata_command'

# list networks in datacenter
class Chef::Knife::DimensiondataTemplateList < Chef::Knife::BaseDimensiondataCommand

  banner "knife dimensiondata template list (options)"

  get_common_options

  option :dc,
         :long => "--datacenter dc_id",
         :description => "Datacenter id where templates should be retrieved from"

  def run
    caas = get_dimensiondata_connection
    if (config[:dc].nil?)
      show_usage
      fatal_exit("You must specify datacenter id for this knife")
    end
    @templates = caas.image.template_list_in_location(config[:dc])
    @templates.map {| template |
      puts "#{ui.color("Template", :cyan)}: #{ui.color("#{template.id}", :red)} - #{template.name} (#{template.cpu_count} cores,#{template.memory_mb}mb memory)"
    }
  end
end
