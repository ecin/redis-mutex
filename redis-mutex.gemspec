lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "redis-mutex"
  spec.version       = "0.0.1"
  spec.authors       = ["ecin"]
  spec.email         = ["ecin@copypastel.com"]
  spec.description   = "Redis-backed mutex."
  spec.summary       = "Redis-backed mutex, compatible with Ruby's Mutex interface."
  spec.homepage      = "https://github.com/ecin/redis-mutex"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "redis", "~> 3.1.0"

  spec.add_development_dependency "bundler", "~> 1.7.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry"
end
