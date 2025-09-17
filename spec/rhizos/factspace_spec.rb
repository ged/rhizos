# -*- ruby -*-

require_relative '../spec_helper'

require 'kuzu'
require 'pluggability'
require 'securerandom'
require 'rhizos/factspace'
require 'rhizos/constants'
require 'rhizos/refinements'

using Rhizos::NumericRefinements

RSpec.describe( Rhizos::Factspace ) do


	after( :each ) do
		GC.start # Try to ensure databases get cleaned up
	end


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
		instance = described_class.setup
		expect( instance.domains ).to include( an_instance_of Rhizos::Domain::Default )
	end


	it "attempts to load any user domains specified" do
		expect {
			described_class.new( domains: %i[archery rowing] )
		}.to raise_error( Pluggability::PluginError, /couldn't find a domain/i )
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


	describe "timers" do

		it "allows registration of a periodic callback as a timer" do
			instance = described_class.setup

			it_was_called = false
			callback = ->( * ) {
				it_was_called = true
			}

			timer = instance.add_periodic_timer( 15.seconds, &callback )

			expect( timer ).to be_a( Rhizos::Timer )
			expect( timer.interval ).to eq( 15 )
			expect { timer.fire }.to change { it_was_called }.to( true )
		end


		it "starts a timer immediately if registered with a running Factspace" do
			begin
				instance = described_class.start

				it_was_called = false
				callback = ->( * ) {
					it_was_called = true
				}

				expect {
					 instance.add_periodic_timer( 15.seconds, &callback )
					 sleep 0.1
				}.to change {
					it_was_called
				}.to( true )
			ensure
				instance&.stop
			end
		end


		it "allows cancellation of a timer" do
			instance = described_class.setup

			timer = instance.add_periodic_timer( 15.seconds ) {}
			expect( timer ).to be_a( Rhizos::Timer )

			expect {
				instance.cancel_periodic_timer( timer )
			}.to change { instance.timers.count }.by( -1 )

			expect( timer ).to be_stopped
		end


		it "starts all registered timers at startup" do
			instance = described_class.setup

			timer1 = instance.add_periodic_timer( 1 ) {}
			timer2 = instance.add_periodic_timer( 1 ) {}

			expect( timer1 ).to be_stopped
			expect( timer2 ).to be_stopped

			begin
				instance.start
				expect( timer1 ).to be_started
				expect( timer2 ).to be_started
			ensure
				instance.stop
			end
		end


		it "cancels all registered timers when it stops" do
			begin
				instance = described_class.start

				timer1 = instance.add_periodic_timer( 1 ) {}
				timer2 = instance.add_periodic_timer( 1 ) {}

				expect( timer1 ).to be_started
				expect( timer2 ).to be_started
			ensure
				instance&.stop
			end

			expect( timer1 ).to be_stopped
			expect( timer2 ).to be_stopped
		end
	end


	describe "high-level convenience methods" do

		it "can return an Array of Fact nodes" do
			instance = described_class.setup

			instance.conn.run( <<~END_OF_QUERY )
				CREATE (:Actor {identifier: "a short-lived system"})
					-[:IS_A]->(:Fact {confidence: 100})
					-[:HAS_A]->(:Lifetime {
						description: "I only run for a few seconds",
						beginsAt: current_timestamp(),
						endsAt: current_timestamp() + INTERVAL('5 seconds')
					});
				CREATE (:Fact {confidence: 100})
					-[l:HAS_A]->(life:Lifetime { description: "I last until deleted" });
				CREATE (:Fact {confidence: 20});
			END_OF_QUERY

			nodes = instance.facts

			expect( nodes ).to be_an( Array ).and( all be_a(Kuzu::Node) )

			nodes.each do |node|
				expect( node.properties ).to include( :id, :confidence )
				expect( node[:id] ).to be_a_uuid
				expect( node[:confidence] ).to be_an( Integer )
			end
		end


		it "can return an Array of Lifetime nodes" do
			instance = described_class.setup

			instance.conn.run( <<~END_OF_QUERY )
				CREATE (:Actor {identifier: "a short-lived system"})
					-[:IS_A]->(:Fact {confidence: 100})
					-[:HAS_A]->(:Lifetime {
						description: "I only run for a few seconds",
						beginsAt: current_timestamp(),
						endsAt: current_timestamp() + INTERVAL('5 seconds')
					});
				CREATE (:Fact {confidence: 100})
					-[:HAS_A]->(:Lifetime { description: "I last until deleted" });
			END_OF_QUERY

			nodes = instance.lifetimes

			expect( nodes ).to be_an( Array ).and( all be_a(Kuzu::Node) )

			nodes.each do |node|
				expect( node.properties ).to include( :id, :beginsAt, :endsAt, :description )
				expect( node[:id] ).to be_a_uuid
			end
		end


		it "can return an Array of Actor nodes" do
			instance = described_class.setup

			instance.conn.run( <<~END_OF_QUERY )
				CREATE (:Actor {identifier: "a short-lived system"})
					-[:IS_A]->(:Fact {confidence: 100})
					-[:HAS_A]->(:Lifetime {
						description: "I only run for a few seconds",
						beginsAt: current_timestamp(),
						endsAt: current_timestamp() + INTERVAL('5 seconds')
					});
				CREATE (:Actor {identifier: "Acme Drone FR2277"})
					-[:HAS_A]->(:Lifetime { description: "I last until I'm powered off" });
			END_OF_QUERY

			nodes = instance.actors

			expect( nodes ).to be_an( Array ).and( all be_a(Kuzu::Node) )

			nodes.each do |node|
				expect( node.properties ).to include( :id, :identifier, :isLocal )
				expect( node[:id] ).to be_a_uuid
			end
		end

	end

end

