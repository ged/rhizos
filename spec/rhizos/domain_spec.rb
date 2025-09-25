# -*- ruby -*-

require_relative '../spec_helper'

require 'rhizos/domain'
require 'rhizos/domain/default'
require 'rhizos/evolver'


RSpec.describe( Rhizos::Domain ) do

	before( :all ) do
		# Ensure all the real domain classes are loaded so we don't clear them along with
		# the testing ones
		described_class.load_all
	end

	before( :each ) do
		@loaded_domains = described_class.derivatives.dup
		@domain_prefixes = described_class.by_prefix.dup
	end

	after( :each ) do
		described_class.reset_domain_lookup
		described_class.by_prefix.replace( @domain_prefixes )
		described_class.derivatives.replace( @loaded_domains )
	end

	let( :factspace ) { Rhizos::Factspace.setup }


	let!( :social_domain_class ) do
		return Class.new( described_class ) do
			set_temporary_name( "Rhizos::Domain::Social (test class)" )
		end
	end
	let( :social_domain ) { social_domain_class.new(factspace) }


	let!( :careers_domain_class ) do
		return Class.new( described_class ) do
			set_temporary_name( "Rhizos::Domain::Careers (test class)" )
		end
	end
	let( :careers_domain ) { careers_domain_class.new(factspace) }

	let!( :media_domain_class ) do
		return Class.new( described_class ) do
			set_temporary_name( "Rhizos::Domain::Media (test class)" )
		end
	end
	let( :media_domain ) { media_domain_class.new }

	let( :test_domain_classes ) do
		[ social_domain_class, careers_domain_class, media_domain_class ]
	end
	let( :test_domains ) {[ social_domain, careers_domain, media_domain ]}

	let( :default_domain_class ) { described_class.get_subclass(:default) }
	let( :default_domain ) { default_domain_class.new(factspace) }
	let( :all_domains ) { [default_domain] + test_domains }


	it "has a default version" do
		expect( social_domain_class.version ).to eq( '0.0.0' )
	end


	it "uses a VERSION constant for its version if it's set" do
		social_domain_class::VERSION = '111.0.0'
		expect( social_domain_class.version ).to eq( '111.0.0' )
	end


	it "has a default prefix" do
		expect( social_domain_class.prefix ).to be_a( URI )
		expect( social_domain_class.prefix ).to eq( DEFAULT_PREFIX_URI + 'social' )
	end


	it "can override its prefix using a shorthand" do
		social_domain_class.prefix( 'us/social' )
		expect( social_domain_class.prefix ).to eq( DEFAULT_PREFIX_URI + 'us/social' )
	end


	it "can override its prefix using a fully-qualified URI" do
		social_domain_class.prefix( 'https://acme.example.com/us/social' )
		expect( social_domain_class.prefix ).to eq( URI('https://acme.example.com/us/social') )
	end


	it "only depends on the default domain by default" do
		expect( social_domain_class.dependencies ).to contain_exactly( DEFAULT_DOMAIN_URI )
	end


	it "can declare additional dependencies using its short name" do
		social_domain_class.requires( :geo )
		expect( social_domain_class.dependencies ).to contain_exactly(
			DEFAULT_DOMAIN_URI,
			DEFAULT_PREFIX_URI + 'geo'
		)
	end


	it "can declare additional dependencies using its shorthand prefix" do
		social_domain_class.requires( 'us/telecommunications' )
		expect( social_domain_class.dependencies ).to contain_exactly(
			DEFAULT_DOMAIN_URI,
			DEFAULT_PREFIX_URI + 'us/telecommunications'
		)
	end


	it "can declare additional dependencies using fully-qualified URIs" do
		social_domain_class.requires( 'https://rhizos.info/us/banking' )
		expect( social_domain_class.dependencies ).to contain_exactly(
			DEFAULT_DOMAIN_URI,
			URI('https://rhizos.info/us/banking')
		)
	end


	it "supports sorting in dependency order" do
		careers_domain_class.requires( :social )
		media_domain_class.requires( :careers, :social )

		dep_order = described_class.sorted

		expect( dep_order ).to order( careers_domain_class ).after( social_domain_class )
		expect( dep_order ).to order( careers_domain_class ).before( media_domain_class )
		expect( dep_order ).to order( social_domain_class ).before( media_domain_class )
	end


	it "can be looked up with its URI prefix" do
		social_domain_class.prefix( 'us/social' )
		expect( described_class.for_uri('https://rhizos.info/us/social') ).to be( social_domain_class )
	end


	it "can be looked up with its shorthand URI prefix" do
		social_domain_class.prefix( 'us/social' )
		expect( described_class.for_uri('us/social') ).to be( social_domain_class )
	end


	it "can be looked up via one of its types' URIs" do
		social_domain_class.prefix( 'us/social' )

		expect( described_class.for_uri('https://rhizos.info/us/social/Post') ).
			to be( social_domain_class )
	end


	it "can be looked up via one of its types' shorthand URIs" do
		social_domain_class.prefix( 'us/social' )

		expect( described_class.for_uri('us/social/Post') ).
			to be( social_domain_class )
	end


	it "updates the domain lookup when a domain declares a new prefix" do
		expect {
			social_domain_class.prefix( 'us/social' )
		}.to change {
			described_class.for_uri( 'https://rhizos.info/us/social/Post' )
		}.from( nil ).to( social_domain_class )
	end



	describe "the factory class" do

		it "can generate a query that installs the schema for one or more domains" do
			result = described_class.collate_schema( Set[social_domain, careers_domain] )
			expect( result ).to respond_to( :cypher )
		end


		it "can generate a query that removes the schema for one or more domains" do
			result = described_class.remove_schema( Set[social_domain, careers_domain] )
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


	describe "evolvers" do

		it "allows access to its evolvers after it is created" do
			social_domain_class.evolver( :lifetime_expirer )
			instance = social_domain_class.new( factspace )

			evolver = instance.get_evolver( :lifetime_expirer )

			expect( evolver ).to be_an_instance_of( Rhizos::Evolver::LifetimeExpirer )
		end


		it "returns nil for a evolver if none exists with the requested name" do
			instance = social_domain_class.new( factspace )

			expect( instance.get_evolver(:deer_petter) ).to be_nil
		end

	end




end

