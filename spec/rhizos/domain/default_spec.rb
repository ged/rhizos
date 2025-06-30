# -*- ruby -*-

require_relative '../../spec_helper'

require 'rhizos/domain/default'


RSpec.describe( Rhizos::Domain::Default ) do

	it "has a semver-compatible version" do
		expect( described_class.version ).to match( Rhizos::Constants::SEMVER_VERSION_PATTERN )
	end

end

