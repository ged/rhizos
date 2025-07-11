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


		it "sets the default for properties that have one set" do
			instance = described_class.new( :UPDATED_BY )

			instance.add_connection( from: :Fact, to: :Actor )
			instance.add_property( :at, 'timestamp', default: :current_timestamp )

			query = instance.cypher

			expect( query ).to match( /CREATE REL TABLE (?-i:UPDATED_BY) \(.*\);/mi )
			expect( query ).to match( /\(.*at TIMESTAMP DEFAULT current_timestamp\(\).*\)/mi )
		end

	end


	describe "merging" do

		let( :instance1 ) do
			instance = described_class.new( :IS_A, 'type-of relationship' )
			instance.add_connection( from: :Pet, to: :Person )
			instance.add_property( :name, 'string' )
			instance.one_many
			return instance
		end

		let( :instance2 ) do
			instance = described_class.new( :IS_A )
			instance.add_connection( from: :Person, to: :Person )
			instance.one_many
			return instance
		end


		it "can merge two instances with different connections" do
			merged = instance1.merge( instance2 )

			expect( merged ).to be_a( described_class )
			expect( merged ).to_not be( instance1 )
			expect( merged ).to_not be( instance2 )
			expect( merged.connections.size ).to eq( 2 )
			expect( merged.connections ).to contain_exactly( [:Pet, :Person], [:Person, :Person] )
			expect( merged.multiplicity ).to eq( :ONE_MANY )
			expect( merged.description ).to eq( 'type-of relationship' )
		end


		it "can merge in either direction" do
			merged = instance2.merge( instance1 )

			expect( merged ).to be_a( described_class )
			expect( merged ).to_not be( instance1 )
			expect( merged ).to_not be( instance2 )
			expect( merged.connections.size ).to eq( 2 )
			expect( merged.connections ).to contain_exactly( [:Pet, :Person], [:Person, :Person] )
			expect( merged.multiplicity ).to eq( :ONE_MANY )
			expect( merged.description ).to eq( 'type-of relationship' )
		end


		it "fails if they have different names"do
			instance2.name = :HAS_A

			expect {
				instance1.merge( instance2 )
			}.to raise_error( Rhizos::SchemaError, /conflicting names/i )
		end


		it "fails if they have different descriptions set" do
			instance2.description = 'something else'

			expect {
				instance1.merge( instance2 )
			}.to raise_error( Rhizos::SchemaError, /conflicting description/i )
		end


		it "succeeds if they both have the same description" do
			instance2.description = instance1.description.dup

			merged = instance1.merge( instance2 )

			expect( merged ).to be_a( described_class )
			expect( merged.description ).to eq( instance1.description )
		end


		it "fails if they both declare properties" do
			instance2.add_property( :label, 'string' )

			expect {
				instance1.merge( instance2 )
			}.to raise_error( Rhizos::SchemaError, /conflicting property declarations/i )
		end


		it "fails if they have different multiplicities" do
			instance2.one_one

			expect {
				instance1.merge( instance2 )
			}.to raise_error( Rhizos::SchemaError, /conflicting multiplicity declarations/i )
		end

	end

end

