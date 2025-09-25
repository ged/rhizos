# -*- ruby -*-

require 'rspec'
require 'securerandom'
require 'rhizos' unless defined?( Rhizos )


# A collection of RSpec testing utilities for Rhizos domains and other systems.
module Rhizos::Testing

	###############
	module_function
	###############

	### Make a randomly-generated machine id file in the given +directory+.
	def make_tmp_machine_id_file( directory, machine_id=nil )
		machine_id ||= SecureRandom.uuid

		directory = Pathname( directory )
		machine_id_file = directory / 'machine-id'
		machine_id_file.write( machine_id.tr('-', '') )

		Rhizos::Factspace.machine_id_file = machine_id_file
	end

end # module Rhizos::Testing


RSpec.shared_examples( "a Rhizos domain" ) do

	it "has a semver-compatible version" do
		expect( described_class.version ).to match( Rhizos::Constants::SEMVER_VERSION_PATTERN )
	end

end


