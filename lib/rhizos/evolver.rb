# -*- ruby -*-

require 'pluggability'
require 'loggability'


require 'rhizos' unless defined?( Rhizos )
require 'rhizos/refinements'

using Rhizos::StringRefinements


class Rhizos::Evolver
	extend Loggability,
		Pluggability

	# Loggability API -- use the Rhizos logger
	log_to :rhizos

	# Pluggability API -- where to find pluggable evolvers
	plugin_prefixes 'rhizos/evolver'



	### Start evolving the Facts in the given +factspace+. You can override this to
	### register timers to interact with the +factspace+, set up any outside connections,
	### etc.
	def start( factspace )
		# No-op by default
	end


	### Stop evolving Facts in the +factspace+. All the +factspace+'s timers will have
	### stopped already, so you only need to override this method if you need some
	### specific cleanup to happen at shutdown.
	def stop( factspace )
		# No-op by default
	end


	### Return the simplified name of the evolver; this is the same as the Pluggability
	### #plugin_name by default.
	def name
		name = self.class.name.sub( /\A.*::(\w+)/, '\\1' )
		name.sub!( /\A([a-z]\w*)\W.*\z/i, '\1' )

		return name.uncamelcase.downcase
	end

end # class Rhizos::Evolver

