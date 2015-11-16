rm *.gem
sudo gem uninstall knife-dimensiondata
gem build knife-dimensiondata.gemspec
gem install knife-dimensiondata-2.0.0.gem
