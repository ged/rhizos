# -*- encoding: utf-8 -*-
# stub: rhizos 0.1.0.pre.20260529125101 ruby lib

Gem::Specification.new do |s|
  s.name = "rhizos".freeze
  s.version = "0.1.0.pre.20260529125101".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://todo.sr.ht/~ged/Rhizos/browse", "changelog_uri" => "https://deveiate.org/code/rhizos/History_md.html", "documentation_uri" => "https://deveiate.org/code/rhizos/", "homepage_uri" => "https://sr.ht/~ged/Rhizos/", "source_uri" => "https://hg.sr.ht/~ged/Rhizos/browse" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Granger".freeze, "Mahlon E. Smith".freeze]
  s.date = "2026-05-29"
  s.description = "A shared state layer for chaotic networks.".freeze
  s.email = ["ged@FaerieMUD.org".freeze, "mahlon@martini.nu".freeze]
  s.executables = ["rhizos".freeze]
  s.files = ["History.md".freeze, "LICENSE.txt".freeze, "README.md".freeze, "bin/rhizos".freeze, "data/rhizos/domains/default.cypher".freeze, "lib/rhizos.rb".freeze, "lib/rhizos/constants.rb".freeze, "lib/rhizos/domain.rb".freeze, "lib/rhizos/domain/default.rb".freeze, "lib/rhizos/domain/geo.rb".freeze, "lib/rhizos/domain_property_dsl.rb".freeze, "lib/rhizos/domain_relation.rb".freeze, "lib/rhizos/domain_type.rb".freeze, "lib/rhizos/evolver.rb".freeze, "lib/rhizos/evolver/lifetime_expirer.rb".freeze, "lib/rhizos/exceptions.rb".freeze, "lib/rhizos/factspace.rb".freeze, "lib/rhizos/refinements.rb".freeze, "lib/rhizos/testing.rb".freeze, "lib/rhizos/timer.rb".freeze, "spec/rhizos/domain/default_spec.rb".freeze, "spec/rhizos/domain_property_dsl_spec.rb".freeze, "spec/rhizos/domain_relation_spec.rb".freeze, "spec/rhizos/domain_spec.rb".freeze, "spec/rhizos/domain_type_spec.rb".freeze, "spec/rhizos/evolver/lifetime_expirer_spec.rb".freeze, "spec/rhizos/evolver_spec.rb".freeze, "spec/rhizos/factspace_spec.rb".freeze, "spec/rhizos/timer_spec.rb".freeze, "spec/rhizos_spec.rb".freeze, "spec/spec_helper.rb".freeze]
  s.homepage = "https://sr.ht/~ged/Rhizos/".freeze
  s.licenses = ["BSD-3-Clause".freeze]
  s.rubygems_version = "4.0.11".freeze
  s.summary = "A shared state layer for chaotic networks.".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.3".freeze])
  s.add_runtime_dependency(%q<concurrent-ruby-ext>.freeze, ["~> 1.3".freeze])
  s.add_runtime_dependency(%q<configurability>.freeze, ["~> 5.0".freeze])
  s.add_runtime_dependency(%q<ffi-radix_tree>.freeze, ["~> 0.6".freeze])
  s.add_runtime_dependency(%q<loggability>.freeze, ["~> 0.18".freeze])
  s.add_runtime_dependency(%q<mixins>.freeze, ["~> 0.1".freeze])
  s.add_runtime_dependency(%q<pluggability>.freeze, ["~> 0.10".freeze])
  s.add_runtime_dependency(%q<ruby-ladybug>.freeze, ["~> 0.1".freeze])
  s.add_development_dependency(%q<rake-deveiate>.freeze, ["~> 0.10".freeze])
end
