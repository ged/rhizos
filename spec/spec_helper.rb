# -*- ruby -*-

require 'tmpdir'
require 'simplecov' if ENV['COVERAGE']

require 'rspec'
require 'rspec/matchers'

require 'loggability/spechelpers'

require 'rhizos'


module Rhizos::SpecHelpers
	extend Loggability
	include Rhizos::Constants


	log_to :rhizos


	### Inclusion callback -- install some hooks
	def self::included( context )

		# :TODO: Make this conditional on a :tmp_mission_dir spec option?
		context.around( :each ) do |example|
			Rhizos::SpecHelpers.with_temp_runtime_dir( example )
		end

	end


	###############
	module_function
	###############

	### Run the specified +example+ with the mission directory set to a tmpdir, cleaning it
	### up when the example is done.
	def with_temp_runtime_dir( example )
		Dir.mktmpdir( ['ravn', 'spec'] ) do |dir|
			machine_id = SecureRandom.uuid
			Rhizos::SpecHelpers.log.info "Machine ID is: %s" % [ machine_id ]

			test_runtime_dir = Pathname( dir )
			Rhizos::SpecHelpers.log.info "Test runtime directory is: %p" % [ test_runtime_dir ]

			machine_id_file = test_runtime_dir / 'machine-id'
			machine_id_file.write( machine_id.tr('-', '') )

			Rhizos::Factspace.machine_id_file = machine_id_file

			Dir.chdir do
				example.run
			end
		end
	end


	RSpec::Matchers.define( :be_a_uuid ) do
		match do |object|
			UUID_PATTERN.match?( object.to_s )
		end
	end

end # module Rhizos::SpecHelpers



### Mock with RSpec
RSpec.configure do |config|
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

	config.include( Rhizos::SpecHelpers )
	config.include( Loggability::SpecHelpers )
end


