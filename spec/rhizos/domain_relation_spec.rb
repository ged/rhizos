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


	it "can have properties added to it" do
		instance = described_class.new( :IS_A, "type-of relation" )

		instance.add_property( :label, 'string' )
		instance.add_property( :ordinal, 'int32' )

		expect( instance.properties.size ).to eq( 2 )
		expect( instance.properties ).to all( be_a described_class::Property )
		expect( instance.properties.map(&:name) ).to contain_exactly( :label, :ordinal )
	end


	it "can specify a multiplicity of ONE_MANY" do
		instance = described_class.new( :IS_A, "type-of relation" )

		expect { instance.one_many }.to change { instance.multiplicity }.to( :ONE_MANY )
	end


	it "can specify a multiplicity of MANY_MANY" do
		instance = described_class.new( :IS_A, "type-of relation" )

		expect { instance.many_many }.to change { instance.multiplicity }.to( :MANY_MANY )
	end


	it "can specify a multiplicity of MANY_ONE" do
		instance = described_class.new( :IS_A, "type-of relation" )

		expect { instance.many_one }.to change { instance.multiplicity }.to( :MANY_ONE )
	end


	it "can specify a multiplicity of ONE_ONE" do
		instance = described_class.new( :IS_A, "type-of relation" )

		expect { instance.one_one }.to change { instance.multiplicity }.to( :ONE_ONE )
	end


	describe "cypher generation" do

		it "doesn't generate anything if it has no connections" do
			instance = described_class.new( :IS_A )

			query = instance.cypher

			expect( query ).to be_nil
		end


		it "generates a REL table with its connections" do
			instance = described_class.new( :IS_A )

			instance.add_connection( from: :Person, to: :Fact )
			instance.add_connection( from: :Pet, to: :Fact )

			query = instance.cypher

			expect( query ).to match( /CREATE REL TABLE (?-i:IS_A) \(.*\);/mi )
			expect( query ).to match( /\(.*from Person to Fact.*\)/mi )
			expect( query ).to match( /\(.*from Pet to Fact.*\)/mi )
		end


		it "generates the REL table with any declared properties" do
			instance = described_class.new( :HAS_A )

			instance.add_connection( from: :Pet, to: :Person )

			instance.add_property( :label, 'string' )
			instance.add_property( :ordinal, 'int32' )

			query = instance.cypher

			expect( query ).to match( /CREATE REL TABLE (?-i:HAS_A) \(.*\);/mi )
			expect( query ).to match( /\(.*from Pet to Person,.*label STRING.*\)/mi )
			expect( query ).to match( /\(.*ordinal INT32.*\)/mi )
		end


		it "generates a multiplicity specifier if one is set" do
			instance = described_class.new( :HAS_A )

			instance.add_connection( from: :Pet, to: :Person )

			instance.many_one

			query = instance.cypher

			expect( query ).to match( /CREATE REL TABLE (?-i:HAS_A) \(.*\);/mi )
			expect( query ).to match( /\(.*MANY_ONE.*\)/mi )
		end

	end


end

