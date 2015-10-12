#
# Author:: Phillip Spies (<phillip.spies@dimensiondata.com>)
# License:: Apache License, Version 2.0
#

require 'dimensiondata'

module DeploymentHelper
  def self.wait_for_deploy(workload, caas_connection, timeout, sleep_time)

    wait = true
    waited_seconds = 0

    print 'Waiting for workload to deploy...'
    while wait

      @workload = caas_connection.server2.show(workload.id)
      if @workload.state == "NORMAL"
        wait = false
      elsif waited_seconds >= timeout
        abort "\nCustomization of VM #{vm.name} not succeeded within #{timeout} seconds."
      else
        print '.'
        sleep(sleep_time)
        waited_seconds += sleep_time
      end
    end
  end
end