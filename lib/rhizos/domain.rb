# -*- ruby -*-

require 'loggability'
require 'pluggability'
require 'mixins'

require 'rhizos' unless defined?( Rhizos )
require 'rhizos/constants'
require 'rhizos/domain_type'
require 'rhizos/domain_relation'


class Rhizos::Domain
	extend Loggability,
		Pluggability,
		Mixins::MethodUtilities
	include Rhizos::Constants,
		Mixins::Inspection


	# Pluggability API -- what path to load domains from
	plugin_prefixes 'rhizos/domain'

	# Loggability API -- Use the Rhizos logger
	log_to :rhizos


	### Set up some class-instance data for all subclasses.
	def self::inherited( subclass )
		super

		subclass.singleton_attr_accessor( :types )
		subclass.types = {}

		subclass.singleton_attr_accessor( :relations )
		subclass.relations = Hash.new do |hash,name|
			hash[ name ] = Rhizos::DomainRelation.new( name )
		end

	end


	### Return the version of the domain, which should be a semver-compatible
	### String.
	def self::version( new_version=nil )
		if new_version
			@version = new_version
		else
			return @version ||= begin
				if self.const_defined?( :VERSION, true )
					self.const_get( :VERSION, true )
				else
					"0.0.0"
				end
			end
		end
	end


	### Declare a node type for the domain with the given +name+ and +description+. If the `:is`
	### option is given, register an :IS_A REL for the type to the specified type.
	def self::type( name, description, is_a: nil, &block )
		source = self.name ? Object.const_source_location( self.name ) : "(unknown)"
		type = Rhizos::DomainType.new( name, description, source: source )
		type.instance_eval( &block ) if block

		self.types[ name.to_sym ] = type

		self.rel( :IS_A, from: name.to_sym, to: is_a ) if is_a
	end
	singleton_method_alias :node, :type


	### Declare a relationship type for the domain with the given
	def self::relation( name, description=nil, **options, &block )
		case options
		in {}
			self.log.debug "Adding a %p REL" % [ name ]
			self.relations[ name ].description = description if description

		in {from: Symbol, to: Symbol}
			self.log.debug "Adding a %p REL from %p to %p" % [ name, options[:from], options[:to] ]
			self.relations[ name ].add( **options )

		else
			raise "Rel with options: %p not yet supported." % [ options ]
		end
	end
	singleton_method_alias :rel, :relation


	### Returns +true+ if there is a Rhizos schema installed in the Factspace's database
	def self::schema_is_installed?( factspace )
		query_obj = Rhizos.query( SHOW_TABLES_QUERY )
		results = factspace.query( query_obj )
		return results.any? {|tuple| tuple['name'] == DOMAIN_INFO_TABLE }
	end


	### Return a Hash of the installed schema information.
	def self::schema_info_hash( factspace )
		query_obj = Rhizos.query( DOMAIN_INFO_MATCH_QUERY )
		results = factspace.query( query_obj )

		domain_info = results.map do |tuple|
			tuple.values_at( 'name', 'version' )
		end

		return Hash[ domain_info ]
	end


	### Collate all the nodes and rel types from the specifed +domains+ and return
	### a query object that can be used to install them in a Kuzu database.
	def self::collate_schema( *domains )
		domains = domains.flatten.map( &:class )

		self.log.debug "Collating schemata from domains: %p" % [ domains ]
		type_chunks = self.collate_schema_types( domains )
		rel_chunks = self.collate_schema_relations( domains )
		schema_query = ( type_chunks + rel_chunks ).join( "\n\n" )

		# schema_file = Rhizos.data_dir + 'domains/default.cypher'
		# schema_query = schema_file.read

		self.log.debug "Schema is: \n---\n%s\n---\n" % [ schema_query ]
		return Rhizos.query( schema_query )
	end


	### Collate the types from the specified +domain_classes+ and return chunks of
	### Cypher source.
	def self::collate_schema_types( domain_classes )
		merged = {}

		domain_classes.each do |domain|
			merged.merge!( domain.types ) do |name, old_type, new_type|
				raise Rhizos::SchemaError, "%s (from %s) type collides with %s (from %s)" %
					[ new_type.name, new_type.source, old_type.name, old_type.source ]
			end
		end

		return merged.values.map( &:cypher )
	end


	### Collate the relations from the specified +domain_classes+ and return chunks of
	### Cypher source.
	def self::collate_schema_relations( domain_classes )
		merged = domain_classes.inject( {} ) do |accum, domain|
			accum.merge( domain.relations ) do |name, old_rel, new_rel|
				old_rel.merge( new_rel )
			end
		end

		return merged.values.map( &:cypher )
	end


	### Collate all the types and relations from the specified +domains+ and return a
	### query object that can be used to remove them.
	def self::remove_schema( *domains )
		delete_query = %{MATCH (n) WHERE LABEL(n) <> "%s" DETACH DELETE n} % [ DOMAIN_INFO_TABLE ]
		return Rhizos.query( delete_query )
	end


	### Return any Rhizos::Evolvers provided by this domain. Returns an empty Array
	### by default.
	def evolvers
		return []
	end


	### Return the simplified name of the domain; this is the same as the Pluggability
	### #plugin_name by default.
	def name
		name = self.class.name.sub( /\A.*::(\w+)/, '\\1' )
		name.sub!( /\A([a-z]\w*)\W.*\z/i, '\1' )

		return name.downcase
	end


	### Return the version for this domain. This should be a semver compatible
	### String.
	def version
		return self.class.version
	end


	### Mixins::Inspection API -- Return the details for inspection output.
	def inspect_details
		return "version: %s, %d types, %d relations" % [
			self.version,
			self.class.types.length,
			self.class.relations.length,
		]
	end

end # class Rhizos::Domain


