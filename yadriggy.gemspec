# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'yadriggy/version'

Gem::Specification.new do |spec|
  spec.name          = "yadriggy"
  spec.version       = Yadriggy::VERSION
  spec.authors       = ["Shigeru Chiba"]
# spec.email         = ["?"]

  spec.summary       = %q{library for building a DSL embedded in Ruby.}

  spec.description   = %q{Yadriggy builds the abstract syntax tree (AST) of a method, checks its syntax and types as a domain specific language (DSL), and runs it.  It also provide a simple DSL for computation offloading from Ruby to C.}

  spec.homepage      = "https://github.com/csg-tokyo/yadriggy"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|examples)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ffi"
  spec.add_dependency "pry"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  # spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "test-unit", "~> 3.2.5"
end
