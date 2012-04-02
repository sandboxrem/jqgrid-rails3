require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the 2dc_jqgrid plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the 2dc_jqgrid plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = '2dcJqgrid'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end


begin
  require "jeweler"
  Jeweler::Tasks.new do |gem|
    gem.name = "jqgrid-rails3"
    gem.summary     = "jQuery grid plugin for rails 3 packed as gem."
    gem.description = "jQuery grid plugin for rails 3 packed as gem."
    gem.files = Dir["{lib}/**/*", "{public}/**/*", "{spec}/**/*", "{test}/**/*"]
    # other fields that would normally go in your gemspec
    # like authors, email and has_rdoc can also be included here
    gem.authors = "Anthony Heukmes"
    gem.email = "KharkivReM@gmail.com"
    gem.homepage    = "http://www.2dconcept.com/jquery-grid-rails-plugin"
    gem.require_paths = [%q{lib}]
    gem.files.exclude "Rakefile"
    gem.files.exclude "VERSION"
    gem.files.exclude "MIT-LICENSE"
    gem.files.exclude "Gemfile.lock"
  end
rescue
  puts "Jeweler or one of its dependencies is not installed."
end
