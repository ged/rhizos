# -*- ruby -*-

require 'loggability'
require 'pluggability'

require 'rhizos' unless defined?( Rhizos )



class Rhizos::Domain
	extend Loggability,
		Pluggability


	# A temporary placeholder object used in place of the eventual monadic query
	# composer (library? class?)
	QueryPlaceholder = Struct.new( 'QueryPlaceholder', :cypher )


	# Pluggability API -- what path to load domains from
	plugin_prefixes 'rhizos/domain'



	### (Undocumented)
	def self::type( * )
		# :TODO:
	end


	### (Undocumented)
	def self::rel( * )
		# :TODO:
	end


	### Collate all the nodes and edge types from the specifed +domains+ and return
	### a query object that can be used to install them.
	def self::collate_schema( domains )
		schema_file = Rhizos.data_dir + 'domains/default.cypher'
		schema = schema_file.read

		return QueryPlaceholder.new( cypher: schema )
	end



	### Return any Rhizos::Evolvers provided by this domain. Returns an empty Array
	### by default.
	def evolvers
		return []
	end

end # class Rhizos::Domain


