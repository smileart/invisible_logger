# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'invisible_logger'

Gem::Specification.new do |spec|
  spec.name          = 'invisible_logger'
  spec.version       = InvisibleLogger::VERSION
  spec.authors       = ['smileart']
  spec.email         = ['smileart21@gmail.com']

  spec.summary       = 'A tool to minimise logs footprint in the host code'
  spec.description   = 'A tool to output complex logs with minimal intrusion and smallest possible ' \
    'footprint in the "host" code + additional ability to aggregate separate logs'
  spec.homepage      = 'http://github.com/smileart/invisible_logger'
  spec.license       = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler',        '~> 1.16'
  spec.add_development_dependency 'byebug',         '~> 9.1'
  spec.add_development_dependency 'inch',           '>= 0.8.0.rc2'
  spec.add_development_dependency 'letters',        '~> 0.4'
  spec.add_development_dependency 'rake',           '~> 12.2'
  spec.add_development_dependency 'rspec',          '~> 3.7'
  spec.add_development_dependency 'rubocop',        '~> 0.51'
  spec.add_development_dependency 'rubygems-tasks', '~> 0.2'
  spec.add_development_dependency 'simplecov',      '~> 0.15'
  spec.add_development_dependency 'timecop',        '~> 0.9'
  spec.add_development_dependency 'yard',           '~> 0.9'
end
