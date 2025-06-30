# -*- ruby -*-

require 'rhizos' unless defined?( Rhizos )


module Rhizos

	### Base class for exceptions in Rhizos classes.
	class Error < RuntimeError; end


	### An error with a domain.
	class DomainError < Rhizos::Error; end


	### An error with the Kuzu database schema
	class SchemaError < Rhizos::Error; end

end # module Rhizos


