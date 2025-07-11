# -*- ruby -*-

require_relative '../spec_helper'

require 'rhizos/domain_property_dsl'


RSpec.describe( Rhizos::DomainPropertyDSL ) do

	let( :including_class ) do
		klass = Class.new
		klass.include( described_class )
		klass
	end
	let( :including_object ) do
		including_class.new
	end


	it "has an alias for int -> int32"


	it "generates a function default for Symbol defaults" do
		result = including_object.stringify_default( :current_timestamp )

		expect( result ).to eq( 'current_timestamp()' )
	end


	it "generates an appropriate literal for String defaults" do
		result = including_object.stringify_default( "(none specified)" )

		expect( result ).to eq( %{"(none specified)"} )
	end


	it "generates an appropriate literal for Integer defaults" do
		result = including_object.stringify_default( 444 )

		expect( result ).to eq( '444' )
	end

end

