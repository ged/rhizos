# -*- ruby -*-

require 'rspec'
require 'rhizos' unless defined?( Rhizos )


# A collection of RSpec testing utilities for Rhizos domains and other systems.
module Rhizos::Testing



end # module Rhizos::Testing


RSpec.shared_examples( "a Rhizos domain" ) do

	it "has a semver-compatible version" do
		expect( described_class.version ).to match( Rhizos::Constants::SEMVER_VERSION_PATTERN )
	end

end


