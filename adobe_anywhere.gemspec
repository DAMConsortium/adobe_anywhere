# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'adobe_anywhere/version'

Gem::Specification.new do |spec|
  spec.name          = 'adobe_anywhere'
  spec.version       = AdobeAnywhere::VERSION
  spec.licenses      = ['']
  spec.authors       = ['John Whitson', 'Nicholas Stokes']
  spec.email         = %w(john.whitson@gmail.com)
  spec.homepage      = ''
  spec.description   = %q{A library for accessing the AdobeAnywhere API}
  spec.summary       = %q{The library consists of a module and executables for interacting with the AdobeAnywhere API }

  spec.required_ruby_version  = '>= 1.8.7'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  # MIG GEM REQUIREMENT. REMOVE ONCE MIG HAS BEEN DEPLOYED AS A GEM
  spec.add_dependency 'ruby-filemagic', '~> 0.4'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
