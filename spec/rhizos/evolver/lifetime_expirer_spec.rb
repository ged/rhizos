# -*- ruby -*-

require_relative '../../spec_helper'

require 'rhizos/evolver/lifetime_expirer'


RSpec.describe( Rhizos::Evolver::LifetimeExpirer ) do

	let( :factspace ) { Rhizos::Factspace.setup }
	let( :instance ) { factspace.get_evolver(:lifetime_expirer) }
	let( :db ) { factspace.conn }


	it "expires Lifetimes that have ended" do
		db.run( <<~END_OF_QUERY )
			CREATE (a:Actor {identifier: "a short-lived system"})
				-[i:IS_A]->(f:Fact {confidence: 100})
				-[l:HAS_A]->(life:Lifetime {
					description: "I only run for a few seconds",
					beginsAt: current_timestamp() - INTERVAL('5 seconds'),
					endsAt: current_timestamp() - INTERVAL('1 second')
				})
			RETURN life.id
		END_OF_QUERY

		expect {
			instance.expire_lifetimes( factspace )
		}.to change {
			factspace.lifetimes.size
		}.from( 2 ).to( 1 )
	end


	it "deletes Facts that no longer have a Lifetime" do
		db.run( <<~END_OF_QUERY )
			CREATE (f:Fact {confidence: 100})
			RETURN f.id
		END_OF_QUERY

		expect {
			instance.remove_facts_with_no_lifetime( factspace )
		}.to change {
			factspace.facts.size
		}.from( 2 ).to( 1 )
	end

end

