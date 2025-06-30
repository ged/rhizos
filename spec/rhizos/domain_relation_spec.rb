# -*- ruby -*-

require_relative '../spec_helper'

require 'rhizos/domain_relation'


RSpec.describe( Rhizos::DomainRelation ) do

	it "can be created with just a name" do
		instance = described_class.new( :IS_A )

		expect( instance ).to be_a( described_class )
		expect( instance.name ).to eq( :IS_A )
		expect( instance.description ).to be_nil
	end


	it "can be created with just a String name" do
		instance = described_class.new( 'IS_A' )

		expect( instance ).to be_a( described_class )
		expect( instance.name ).to eq( :IS_A )
		expect( instance.description ).to be_nil
	end


	it "can be created with a description" do
		instance = described_class.new( :IS_A, "type-of relations" )

		expect( instance ).to be_a( described_class )
		expect( instance.name ).to eq( :IS_A )
		expect( instance.description ).to eq( "type-of relations" )
	end


	it "has no properties by default" do
		instance = described_class.new( :IS_A, "a human being" )

		expect( instance.properties ).to be_empty
	end


	describe "cypher generation" do

		it "doesn't generate anything if it has no connections" do
			instance = described_class.new( :IS_A )

			query = instance.cypher

			expect( query ).to be_nil
		end


		it "generates a REL table with its connections" do
			instance = described_class.new( :IS_A )

			instance.add( from: :Person, to: :Fact )
			instance.add( from: :Pet, to: :Fact )

			query = instance.cypher

			expect( query ).to match( /CREATE REL TABLE (?-i:IS_A) \(.*\);/mi )
			expect( query ).to match( /\(.*from Person to Fact.*\)/mi )
			expect( query ).to match( /\(.*from Pet to Fact.*\)/mi )
		end

	end


end

