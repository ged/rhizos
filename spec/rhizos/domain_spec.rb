# -*- ruby -*-

require_relative '../spec_helper'

require 'rhizos/domain'
require 'rhizos/domain/default'
require 'rhizos/evolver'


RSpec.describe( Rhizos::Domain ) do

	before( :each ) do
		@loaded_domains = described_class.derivatives.dup
	end

	after( :each ) do
		described_class.derivatives.replace( @loaded_domains )
	end


	let( :social_domain_class ) do
		klass = Class.new( described_class )
		klass.set_temporary_name( "Rhizos::Domain::Social (test class)" )
		return klass
	end
	let( :social_domain ) { social_domain_class.new }


	let( :careers_domain_class ) do
		klass = Class.new( described_class )
		klass.set_temporary_name( "Rhizos::Domain::Careers (test class)" )
		return klass
	end
	let( :careers_domain ) { careers_domain_class.new }


	let( :test_domain_classes ) {[ social_domain_class, careers_domain_class ]}
	let( :test_domains ) {[ social_domain, careers_domain ]}


	it "has a default version" do
		expect( social_domain_class.version ).to eq( '0.0.0' )
	end


	it "uses a VERSION constant for its version if it's set" do
		social_domain_class::VERSION = '111.0.0'
		expect( social_domain_class.version ).to eq( '111.0.0' )
	end


	describe "the factory class" do

		it "can generate a query that installs the schema for one or more domains" do
			result = described_class.collate_schema( social_domain, careers_domain )
			expect( result ).to respond_to( :cypher )
		end


		it "can generate a query that removes the schema for one or more domains" do
			result = described_class.remove_schema( social_domain, careers_domain )
			expect( result ).to respond_to( :cypher )
		end


		it "knows if a schema is installed for a Factspace" do
			factspace = Rhizos::Factspace.new
			factspace.setup

			expect( described_class.schema_is_installed?(factspace) )
		end


		it "can return a Hash of schema info read from a Factspace" do
			factspace = Rhizos::Factspace.new( domains: test_domain_classes )
			factspace.setup

			result = described_class.schema_info_hash( factspace )

			expect( result ).to be_a( Hash )
			expect( result ).to include( 'default' )
			expect( result ).to include( 'social' )
			expect( result ).to include( 'careers' )
		end

	end


	describe "schema DSL" do

		let( :a_domain_class ) do
			Class.new( described_class ) do
				set_temporary_name 'Rhizos::Domain::Social (testing class)'
			end
		end


		it "can declare its version" do
			a_domain_class.version( '244.44.44' )
			expect( a_domain_class.version ).to eq( '244.44.44' )
		end


		it "knows what nodes types it contains" do
			expect( a_domain_class.types ).to be_a( Hash )
		end


		it "can declare node types" do
			a_domain_class.type( :Person, "a human" ) do
				string :first_name
				string :last_name
				int8 :age
			end

			types = a_domain_class.types

			expect( types ).to include( :Person )
			expect( types[:Person].properties ).to include( a_property_named(:first_name) )
		end


		it "can declare an IS_A relationship separately" do
			a_domain_class.type( :Person, "a human" ) do
				string :first_name
				string :last_name
				int8 :age
			end

			a_domain_class.rel( :IS_A, from: :Person, to: :Fact )

			expect( a_domain_class.types ).to include( :Person )

			expect( a_domain_class ).to have_a_relation_named( :IS_A ).from( :Person ).to( :Fact )
		end


		it "has a convenience for declaring a node type that's a Fact" do
			a_domain_class.type( :Person, "a human", is_a: :Fact ) do
				string :first_name
				string :last_name
				int8 :age
			end

			expect( a_domain_class.types ).to include( :Person )
			expect( a_domain_class ).to have_a_relation_named( :IS_A ).from( :Person ).to( :Fact )
		end


		it "can declare a HAS_A relationship" do
			a_domain_class.type( :Person, "a human" )
			a_domain_class.type( :Pet, "a non-human" )

			a_domain_class.rel( :HAS_A, from: :Pet, to: :Person )

			expect( a_domain_class.types ).to include( :Person, :Pet )
			expect( a_domain_class ).to have_a_relation_named( :HAS_A ).from( :Pet ).to( :Person )
		end


		it "can override the default `id` field"


		it "can declare an Evolver type" do
			pet_feeder_evolver = Class.new( Rhizos::Evolver ) do
				Loggability.log.debug "Setting temporary name."
				set_temporary_name( "Rhizos::Evolver::PetFeeder (testing class)" )
			end

			a_domain_class.evolver( :PetFeeder )

			expect( a_domain_class.evolvers ).to include( :PetFeeder => pet_feeder_evolver )
		end

	end


end

