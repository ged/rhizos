# -*- ruby -*-

require 'loggability'

require 'rhizos/evolver' unless defined?( Rhizos::Evolver )


# An evolver that cleans up Facts whose Lifetime has expired.
#
# A Lifetimes is expired if:
#
# - it has an `endsAt` that is in the past
#
class Rhizos::Evolver::Expirer < Rhizos::Evolver


	EXPIRED_FACT_QUERY = <<~END_OF_QUERY
		MATCH (f:Fact)-[:HAS_A]->(life:Lifetime)
		WHERE life.endsAt < current_timestamp()
		RETURN f.id;
	END_OF_QUERY

	FACTS_WITHOUT_LIFETIME = <<~END_OF_QUERY
		MATCH (f:Fact)
		WHERE NOT EXISTS {
			(fact)-[:HAS_A]->(:Lifetime)
		}
		RETURN f.id;
	END_OF_QUERY


	### Start the evolver in the specified +factspace+.
	def start( factspace )
		a_query = Rhizos.query( EXPIRED_FACT_QUERY )
		another_query = Rhizos::SequelStyleQuery.
			new( "select other_thing where $foo", &self.method(:prepare_other_query) )

		# Tick-based evolver
		factspace.register_query( self, a_query )
		factspace.register_query( self, another_query )
	end




end # class Rhizos::Evolver::Expirer
