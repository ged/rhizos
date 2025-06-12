# -*- ruby -*-

require 'rhizos' unless defined?( Rhizos )


# Useful constants for Rhizos systems.
module Rhizos::Constants

	# Pattern for matching UUIDs.
	UUID_PATTERN = %r{
		\A
		\h{8}
		(?:-\h{4}){3}
		-\h{12}
		\z
	}mx

end # module Rhizos::Constants
