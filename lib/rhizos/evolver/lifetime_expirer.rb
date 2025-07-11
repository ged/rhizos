# -*- ruby -*-

require 'loggability'

require 'rhizos/evolver' unless defined?( Rhizos::Evolver )
require 'rhizos/refinements'

using Rhizos::NumericRefinements


# An evolver that cleans up Facts whose Lifetime has expired.
#
# - A Lifetime is expired if it has an `endsAt` that is in the past
# - A Fact expires if it doesn't have an associated Lifetime.
#
class Rhizos::Evolver::LifetimeExpirer < Rhizos::Evolver

	# How often to run the expiration queries
	RUN_INTERVAL = 15.seconds

	# The query that deletes Lifetimes that have ended
	EXPIRE_LIFETIMES_QUERY = Rhizos.query( <<~END_OF_QUERY )
		MATCH (life:Lifetime)
		WHERE life.endsAt < current_timestamp()
		DETACH DELETE life
		RETURN life.id;
	END_OF_QUERY

	# The query that deletes Facts which no longer have a Lifetime
	REMOVE_FACTS_WITHOUT_LIFETIME = Rhizos.query( <<~END_OF_QUERY )
		MATCH (fact:Fact)
		WHERE NOT (fact:Fact)-[:HAS_A]->(:Lifetime)
		DETACH DELETE fact
		RETURN fact.*;
	END_OF_QUERY


	### Start the evolver in the specified +factspace+.
	def start( factspace )
		factspace.add_periodic_timer( RUN_INTERVAL ) do |timer|
			self.expire_lifetimes( factspace )
			self.remove_facts_with_no_lifetime( factspace )
		end
	end


	### Delete any Lifetimes that are ended in the given +factspace+.
	def expire_lifetimes( factspace )
		results = factspace.query( EXPIRE_LIFETIMES_QUERY )
		self.log.debug "Expired %d Lifetimes (%p)." % [ results.length, results ]
	end


	### Remove any Facts that no longer have an associated Lifetime in the given
	### +factspace+.
	def remove_facts_with_no_lifetime( factspace )
		results = factspace.query( REMOVE_FACTS_WITHOUT_LIFETIME )
		self.log.debug "Expired %d Facts with no Lifetime: %p" % [ results.length, results ]
	end

end # class Rhizos::Evolver::LifetimeExpirer
