# -*- ruby -*-

require_relative '../spec_helper'

require 'rhizos/evolver'
require 'rhizos/factspace'


RSpec.describe( Rhizos::Evolver ) do

	let( :evolver_subclass ) do
		Class.new( described_class ) do
			set_temporary_name 'Rhizos::Evolver::BirdPetter (test class)'
		end
	end

	let( :instance ) { evolver_subclass.new }
	let( :factspace ) { double( Rhizos::Factspace ) }


	it "provides a #start method to hook startup" do
		expect { instance.start(factspace) }.not_to raise_error
	end


	it "provides a #stop method to hook shutdown" do

		expect { instance.stop(factspace) }.not_to raise_error
	end


	it "knows what its key name is" do
		expect( instance.name ).to eq( 'bird_petter' )
	end

end

