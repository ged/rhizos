# -*- ruby -*-

require_relative '../../spec_helper'

require 'rhizos/evolver/lifetime_expirer'


RSpec.describe( Rhizos::Evolver::LifetimeExpirer ) do

	let( :factspace ) { Rhizos::Factspace.setup }
	let( :instance ) { factspace.get_evolver(:lifetime_expirer) }
	let( :db ) { factspace.conn }


	it "expires Lifetimes that have ended"
	it "deletes Facts that no longer have a Lifetime"

end

