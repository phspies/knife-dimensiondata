# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "knife-dimensiondata"
  s.version = "2.0.0"
  s.summary = "Dimension Data Cloud for Knife"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.authors = "Phillip Spies"
  s.description = "Dimension Data Cloud Support for Chef's Knife Command"
  s.email = "phillip.spies@dimensiondata.com"
  s.files = Dir["lib/**/*"]
  s.rubygems_version = "1.6.2"
  s.homepage = 'http://github.com/Silmaril00/knife-dimensiondata'
  s.license = 'Apache'
  s.add_dependency('netaddr', ["~> 1.5.0"])
  s.add_dependency('chef', [">= 0.10.0"])
  s.add_dependency('dimensiondata', [">= 2.0.0"])
  s.add_dependency('knife-windows', [">= 1.0.0"])
  s.add_dependency('winrm', [">= 1.3.4"])
end
