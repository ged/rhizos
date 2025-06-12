# -*- ruby -*-

require_relative 'spec_helper'

require 'rspec'
require 'rhizos'


RSpec.describe( Rhizos ) do

	it "has a semantic version" do
		expect( described_class::VERSION ).to match( /\A\d+(?:\.\d+){2}/ )
	end

end

