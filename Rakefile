require "bundler/gem_tasks"
require "rake/testtask"
require "rake/extensiontask"
require "yard"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

YARD::Rake::YardocTask.new do |t|
  t.options = ['-m markdown', '--no-private']
end

Rake::ExtensionTask.new "yadriggy/oops" do |ext|
  ext.name = "yadriggy_oops"
  ext.lib_dir = "lib/yadriggy/oops"
  cp "ext/yadriggy/oops/gc.hpp", ext.lib_dir
end

task :default => :test
