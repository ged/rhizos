# -*- ruby -*-

require 'pluggability'
require 'loggability'


require 'rhizos' unless defined?( Rhizos )



class Rhizos::Evolver
	extend Loggability,
		Pluggability

	# Loggability API -- use the Rhizos logger
	log_to :rhizos

	# Pluggability API -- where to find pluggable evolvers
	plugin_paths 'rhizos/evolver'



	### Start evolving the Facts this Evolver operates on.
	def start( factspace )

		# a_query = Rhizos::SequelStyleQuery.new( "select thing where $variable" ) do |statement|
		# 	statement.bind( variable: Time.now )
		# end
		# another_query = Rhizos::SequelStyleQuery.
		# 	new( "select other_thing where $foo", &self.method(:prepare_other_query) )
		#
		# # Tick-based evolver
		# factspace.register_query( self, a_query )
		# factspace.register_query( self, another_query )
		#
		# # Custom timer based evolver
		# a_timer = factspace.register_timed_query( self, a_query, interval )
		# factspace.cancel_timed_query( a_timer )
	end


	### Run the evolver on the given +facts+, which are the current results of the
	### query registered when it was started.
	def run( facts )
		return facts
	end

end # class Rhizos::Evolver

