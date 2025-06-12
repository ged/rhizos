# -*- encoding: utf-8 -*-
# stub: rhizos 0.1.0.pre.20250612115645 ruby lib

Gem::Specification.new do |s|
  s.name = "rhizos".freeze
  s.version = "0.1.0.pre.20250612115645".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://dev.ravn.com/docs/rhizos/History_md.html", "documentation_uri" => "https://dev.ravn.com/docs/rhizos", "homepage_uri" => "https://github.com/RavnGroup/rhizos", "source_uri" => "https://github.com/RavnGroup/rhizos/" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Granger".freeze, "Mahlon E. Smith".freeze]
  s.date = "2025-06-12"
  s.description = "A shared-state application layer for highly cooperative applications.".freeze
  s.email = ["ged@FaerieMUD.org".freeze, "mahlon@martini.nu".freeze]
  s.files = [".simplecov".freeze, "History.md".freeze, "README.md".freeze, "Rakefile".freeze, "lib/rhizos.rb".freeze, "spec/rhizos_spec.rb".freeze, "spec/spec_helper.rb".freeze]
  s.homepage = "https://github.com/RavnGroup/rhizos".freeze
  s.licenses = ["BSD-3-Clause".freeze]
  s.rubygems_version = "3.6.7".freeze
  s.summary = "A shared-state application layer for highly cooperative applications.".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.3".freeze])
  s.add_runtime_dependency(%q<concurrent-ruby-ext>.freeze, ["~> 1.3".freeze])
  s.add_runtime_dependency(%q<configurability>.freeze, ["~> 5.0".freeze])
  s.add_runtime_dependency(%q<loggability>.freeze, ["~> 0.18".freeze])
  s.add_runtime_dependency(%q<ruby-kuzu>.freeze, ["~> 0.0".freeze])
  s.add_runtime_dependency(%q<pluggability>.freeze, ["~> 0.9".freeze])
  s.add_development_dependency(%q<rake-deveiate>.freeze, ["~> 0.10".freeze])
end
