# -*- ruby -*-

require_relative '../spec_helper'

require 'kuzu'
require 'pluggability'
require 'securerandom'
require 'rhizos/factspace'
require 'rhizos/constants'


RSpec.describe( Rhizos::Factspace ) do


	# Set by the spec helper
	let( :machine_id ) { @machine_id }


	it "can be started" do
		begin
			instance = described_class.start

			expect( instance ).to be_a( described_class )
			expect( instance ).to be_running
			expect( instance.node_id ).to be_a_uuid

			expect { instance.stop }.to change { instance.running? }.to( false )
		ensure
			instance&.stop
		end
	end


	it "always loads the default domain" do
		begin
			instance = described_class.start

			expect( instance.domains ).to include( an_instance_of Rhizos::Domain::Default )
		ensure
			instance&.stop
		end
	end


	it "attempts to load any user domains specified" do
		begin
			instance = described_class.new( domains: %i[archery rowing] )

			expect {
				instance.start
			}.to raise_error( Pluggability::PluginError, /couldn't find a domain/i )
		ensure
			instance&.stop
		end
	end


	it "reuses an existing database if it already has a schema" do
		begin
			previous_instance = described_class.new( db_path: 'test' )
			previous_instance.start
			previous_instance.stop

			instance = described_class.new( db_path: 'test' )
			instance.start

		ensure
			instance&.stop
		end
	end


	it "has an idempotent stop method" do
		instance = described_class.start

		expect {
			instance.stop
			instance.stop
		}.to_not raise_error
	end


	describe "refuses to start with an existing database if" do

		it "had different domains" do
			described_class.setup( db_path: 'test', domains: [:geo] )
			GC.start # Hopefully free the Kuzu::Database

			begin
				instance = nil

				expect {
					instance = described_class.start( db_path: 'test' )
				}.to raise_error( Rhizos::SchemaError, /has domains that are not loaded/i )
			ensure
				instance&.stop
			end
		end


		it "is missing domains" do
			described_class.setup( db_path: 'test' )
			GC.start # Hopefully free the Kuzu::Database

			begin
				instance = nil

				expect {
					instance = described_class.start( db_path: 'test', domains: [:geo] )
				}.to raise_error( Rhizos::SchemaError, /is missing schema for some domains/i )
			ensure
				instance&.stop
			end
		end


		it "had different versions of one or more domains" do
			previous_instance = described_class.setup( db_path: 'test', domains: [:geo] )
			change_version = Rhizos.query( Rhizos::Constants::SET_DOMAIN_VERSION_QUERY )
			previous_instance.query( change_version ) do |stmt|
				stmt.bind( name: 'geo', version: '44.44.44' )
			end
			GC.start # Hopefully free the Kuzu::Database

			begin
				instance = nil

				expect {
					instance = described_class.start( db_path: 'test', domains: [:geo] )
				}.to raise_error( Rhizos::SchemaError, /incompatible versions/i )
			ensure
				instance&.stop
			end
		end

	end


	describe "machine ID handling" do

		it "reads its node ID at setup" do
			instance = described_class.new

			expect {
				instance.setup
			}.to change { instance.node_id }.from( nil ).to( machine_id )
		end


		it "handles UUIDs with dashes" do
			dashed_uuid = SecureRandom.uuid

			# Rewrite with dashes
			described_class.machine_id_file.write( dashed_uuid )
			result = described_class.read_node_id

			expect( result ).to eq( dashed_uuid )
		end


		it "rejects empty machine-id files" do
			described_class.machine_id_file.truncate( 0 )
			expect( described_class.read_node_id ).to be_nil
		end


		it "rejects machine-id files with something other than a UUID" do
			described_class.machine_id_file.write( "HI IM HERE TO SERVE YOU CANTALOUPE" )
			expect( described_class.read_node_id ).to be_nil
		end


		it "rejects machine-id files with only a partial UUID" do
			described_class.machine_id_file.write( SecureRandom.hex(8) )
			expect( described_class.read_node_id ).to be_nil
		end

	end

end

