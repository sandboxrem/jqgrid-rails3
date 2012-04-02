# -*- encoding: utf-8 -*-
require File.expand_path('../lib/jqgrid-rails3/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Anthony Heukmes"]
  gem.email         = ["KharkivReM@gmail.com"]
  gem.description   = %q{jQuery grid plugin for rails 3 packed as gem.}
  gem.summary       = %q{jQuery grid plugin for rails 3 packed as gem.}
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "jqgrid-rails3"
  gem.require_paths = ["lib"]
  gem.version       = Jqgrid::Rails3::VERSION
end
