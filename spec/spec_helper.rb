# -*- ruby -*-

require 'tmpdir'
require 'simplecov' if ENV['COVERAGE']

require 'rspec'
require 'rspec/matchers'

require 'pluggability'
require 'securerandom'
require 'loggability/spechelpers'

require 'rhizos'


module Rhizos::SpecHelpers
	extend Loggability


	# Loggability API -- use the Rhizos logger
	log_to :rhizos


	### Inclusion callback -- install some hooks
	def self::included( context )

		# :TODO: Make this conditional on a :tmp_mission_dir spec option?
		context.around( :each ) do |example|
			@machine_id = SecureRandom.uuid
			Rhizos::SpecHelpers.log.info "Machine ID is: %s" % [ @machine_id ]

			Rhizos::SpecHelpers.with_temp_runtime_dir( @machine_id, example )

			@machine_id = nil
		end

	end


	###############
	module_function
	###############

	### Run the specified +example+ with the mission directory set to a tmpdir, cleaning it
	### up when the example is done.
	def with_temp_runtime_dir( machine_id, example )
		Dir.mktmpdir( ['ravn', 'spec'] ) do |dir|

			test_runtime_dir = Pathname( dir )
			Rhizos::SpecHelpers.log.info "Test runtime directory is: %p" % [ test_runtime_dir ]

			machine_id_file = test_runtime_dir / 'machine-id'
			machine_id_file.write( machine_id.tr('-', '') )

			Rhizos::Factspace.machine_id_file = machine_id_file

			Dir.chdir( dir ) do
				example.run
			end
		end
	end



	RSpec::Matchers.define( :be_a_uuid ) do
		match do |object|
			UUID_PATTERN.match?( object.to_s )
		end
	end



	RSpec::Matchers.define( :a_property_named ) do |expected|
		match do |actual|
			expect( actual ).to be_a( Rhizos::DomainType::Property )
			expect( actual.name ).to eq( expected )
			expect( actual.type ).to eq( expected_type ) unless expected_type.nil?
			true
		end

		chain :of_type, :expected_type
	end


	RSpec::Matchers.define( :have_a_relation_named ) do |relation_name|
		match do |domain_class|
			expect( domain_class.relations ).to include( relation_name )

			relation = domain_class.relations[ relation_name ]
			expect( relation ).to be_a( Rhizos::DomainRelation )
			expect( relation.name ).to eq( relation_name )

			if from_type
				if to_type
					expect( relation.connections ).to include( [from_type, to_type] )
				else
					expect( relation.connections ).to include( [from_type, any()] )
				end
			elsif to_type
				expect( relation.connections ).to include( [any(), to_type] )
			end

			true
		end

		chain :from, :from_type
		chain :to, :to_type
	end


	RSpec::Matchers.define( :order ) do |member|
		match do |collection|
			expect( collection ).to include( member )

			if before_member
				expect( collection.index(member) ).to be < collection.index( before_member )
			elsif after_member
				expect( collection.index(member) ).to be > collection.index( after_member )
			else
				expect( collection.sort ).to eq( collection )
			end
		end

		chain :before, :before_member
		chain :after, :after_member
	end


end # module Rhizos::SpecHelpers



### Mock with RSpec
RSpec.configure do |config|
	include Rhizos::Constants

	config.mock_with( :rspec ) do |mock|
		mock.syntax = :expect
	end

	config.disable_monkey_patching!
	config.example_status_persistence_file_path = "spec/.status"
	config.filter_run :focus
	config.filter_run_when_matching :focus
	config.order = :random
	config.profile_examples = 5
	config.run_all_when_everything_filtered = true
	config.shared_context_metadata_behavior = :apply_to_host_groups
	# config.warnings = true

	config.expect_with( :rspec ) do |expectations|
		expectations.include_chain_clauses_in_custom_matcher_descriptions = true
	end

	config.include( Rhizos::SpecHelpers )
	config.include( Loggability::SpecHelpers )
end


