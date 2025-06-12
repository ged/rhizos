# -*- ruby -*-

require 'kuzu'
require 'loggability'
require 'configurability'
require 'pluggability'
require 'mixins'


# Distributed factspace toolkit
module Rhizos
	extend Loggability,
		Configurability,
		Mixins::Datadir

	# Package version
	VERSION = '0.0.1'


	# Loggability -- Set up a logger for Rhizos objects
	log_as :rhizos


	autoload :Constants, 'rhizos/constants'
	autoload :Factspace, 'rhizos/factspace'
	autoload :Domain, 'rhizos/domain'


	### Construct and return a Rhizos::Factspace using the specified arguments.
	def self::factspace( ... )
		return Rhizos::Factspace.new( ... )
	end

end # module Rhizos

