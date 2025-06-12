# -*- ruby -*-

require_relative '../spec_helper'

require 'securerandom'
require 'rhizos/factspace'


RSpec.describe( Rhizos::Factspace ) do


	it "can be started as a default instance" do
		instance = described_class.start

		expect( instance ).to be_a( described_class )
		expect( instance ).to be_running
		expect( instance.node_id ).to be_a_uuid

		expect { instance.stop }.to change { instance.running? }.to( false )
	end


	describe "machine ID handling" do

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

