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

  def run
    caas = get_dimensiondata_connection
    @domains = caas.network2.list_domains

    case @domains
      when Array
        @domains.each do | domain |
          puts "#{ui.color("DOMAIN", :cyan)}: #{ui.color("#{domain.id}", :red)} - #{domain.name}"
          @vlans = caas.network2.list_vlans_in_domain(domain.id)
          case @vlans
            when Array
              @vlans.each do | vlan |
                puts "    #{ui.color("VLAN", :cyan)}: #{ui.color("#{vlan.id}", :red)} - #{vlan.name}"
              end
            when Hash
              vlan = @vlans
              puts "     #{ui.color("VLAN", :cyan)}: #{ui.color("#{vlan.id}", :red)} - #{vlan.name}"
          end

        end
      when Hash
        domain = @domains
        puts "#{ui.color("DOMAIN", :cyan)}: #{ui.color("#{domain.id}", :red)} - #{domain.name}"
        @vlans = caas.network2.list_vlans_in_domain(domain.id)
        case @vlans
          when Array
            @vlans.each do | vlan |
              puts "    #{ui.color("VLAN", :cyan)}: #{ui.color("#{vlan.id}", :red)} - #{vlan.name}"
            end
          when Hash
            vlan = @vlans
            puts "     #{ui.color("VLAN", :cyan)}: #{ui.color("#{vlan.id}", :red)} - #{vlan.name}"
        end
    end


  end
end
