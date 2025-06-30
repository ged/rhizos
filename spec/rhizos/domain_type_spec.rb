# -*- ruby -*-

require_relative '../spec_helper'

require 'rspec/expectations'
require 'rhizos/domain_type'


RSpec.describe( Rhizos::DomainType ) do

	it "can be created with just a name" do
		instance = described_class.new( :Person )

		expect( instance ).to be_a( described_class )
		expect( instance.name ).to eq( :Person )
		expect( instance.description ).to be_nil
	end


	it "can be created with just a String name" do
		instance = described_class.new( 'Person' )

		expect( instance ).to be_a( described_class )
		expect( instance.name ).to eq( :Person )
		expect( instance.description ).to be_nil
	end


	it "can be created with a description" do
		instance = described_class.new( :Person, "a human being" )

		expect( instance ).to be_a( described_class )
		expect( instance.name ).to eq( :Person )
		expect( instance.description ).to eq( "a human being" )
	end


	it "has an `id` property by default" do
		instance = described_class.new( :Person, "a human being" )

		expect( instance.properties ).to include( a_property_named(:id).of_type('UUID') )
	end


	describe "cypher generation" do

		it "generates a single-property definition by default" do
			instance = described_class.new( :Person )

			query = instance.cypher

			expect( query ).to match( /CREATE NODE TABLE (?-i:Person) \(.*\);/mi )
			expect( query ).to match( /\(.*(?-i:id) UUID DEFAULT (?-i:gen_random_uuid)\(\).*\)/mi )
		end


		it "generates declared properties" do
			instance = described_class.new( :Person )

			instance.timestamp( :created_at, default: :current_timestamp )
			instance.timestamp( :updated_at )
			instance.int8( :confidence, default: 0 )

			query = instance.cypher

			expect( query ).to match( /CREATE NODE TABLE (?-i:Person) \(.*\);/mi )
			expect( query ).to match( /\(.*(?-i:id) UUID DEFAULT (?-i:gen_random_uuid)\(\),.*\)/mi )
			expect( query ).
				to match( /(?-i:created_at) TIMESTAMP DEFAULT (?-i:current_timestamp)\(\),.*\)/mi )
			expect( query ).
				to match( /(?-i:updated_at) TIMESTAMP,.*\)/mi )
			expect( query ).
				to match( /(?-i:confidence) INT8 DEFAULT 0,.*\)/mi )
		end

	end

end

