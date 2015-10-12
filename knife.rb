# See https://docs.chef.io/config_rb_knife.html for more information on knife configuration options

current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "fspies"
client_key               "#{current_dir}/fspies.pem"
validation_client_name   "mcplab-validator"
validation_key           "#{current_dir}/mcplab-validator.pem"
chef_server_url          "https://api.opscode.com/organizations/mcplab"
cookbook_path            ["#{current_dir}/../cookbooks"]


knife[:dimensiondata_url] = "https://api-na.dimensiondata.com"
knife[:dimensiondata_user] = ""
knife[:dimensiondata_pass] = ""
knife[:windows_customization] = "oscustomization.exe"
knife[:linux_customization] = "oscustomization.sh"
