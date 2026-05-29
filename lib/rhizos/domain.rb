# -*- ruby -*-

require 'uri'
require 'set'
require 'tsort'
require 'loggability'
require 'pluggability'
require 'ffi/radix_tree'
require 'mixins'

require 'rhizos' unless defined?( Rhizos )
require 'rhizos/constants'
require 'rhizos/domain_type'
require 'rhizos/domain_relation'


# The base domain class.
class Rhizos::Domain
	extend TSort,
		Loggability,
		Pluggability,
		Mixins::MethodUtilities
	include Rhizos::Constants,
		Mixins::Inspection


	# Pluggability API -- what path to load domains from
	plugin_prefixes 'rhizos/domain'

	# Loggability API -- Use the Rhizos logger
	log_to :rhizos


	# A trie of domain URI prefixes for lookups, built on demand
	@uri_trie = nil

	# A Hash of domains keyed by their URI prefix
	@by_prefix = {}
	singleton_attr_reader :by_prefix


	##
	# Declared dependencies (empty for the base class)
	singleton_attr_accessor :dependencies
	@dependencies = Set.new

	##
	# The domain's types
	singleton_attr_accessor :types

	##
	# The domain's relations
	singleton_attr_accessor :relations

	##
	# The domain's evolvers
	singleton_attr_accessor :evolvers


	### Set up some class-instance data for all subclasses.
	def self::inherited( subclass )
		super

		subclass.types = {}
		subclass.relations = Hash.new do |hash, name|
			hash[ name ] = Rhizos::DomainRelation.new( name )
		end
		subclass.evolvers = {}
		subclass.dependencies = Set.new( [DEFAULT_DOMAIN_URI] )
	end


	### Pluggability hook -- override the plugin registration to also add the
	### domain prefix lookup.
	def self::register_plugin_type( subclass )
		super

		if subclass.plugin_name && subclass.plugin_name.is_a?( String )
			self.log.debug "Adding initial prefix for %p (%p)" % [ subclass, subclass.plugin_name ]
			initial_prefix = DEFAULT_PREFIX_URI + subclass.plugin_name
			subclass.prefix( initial_prefix )
		end
	end


	#
	# Domain DSL
	#

	### Return the version of the domain, which should be a semver-compatible
	### String.
	def self::version( new_version=nil )
		if new_version
			@version = new_version
		else
			return @version ||= begin
				if self.const_defined?( :VERSION, false )
					self.log.debug "Using VERSION constant for domain version"
					self.const_get( :VERSION, false )
				else
					'0.0.0'
				end
			end
		end
	end


	### Mark a dependency of this domain on one or more other +domains+.
	def self::requires( *domains )
		self.log.debug "Adding dependency on %p" % [ domains ]
		domains = domains.flatten.map {|raw| self.qualify_domain_uri(raw) }
		self.dependencies.merge( domains )
	end


	### If +uri+ is given, declare that types in this domain have the specified
	### +uri+ prefix. If the +uri+ is not an absolute URI, prepend the DEFAULT_PREFIX_URI,
	### otherwise use it as-is. Returns the current prefix.
	def self::prefix( uri=nil )
		if uri
			Rhizos::Domain.reset_domain_lookup

			if @prefix
				self.log.warn "Replacing previous prefix %p for %p" % [ @prefix, self ]
				Rhizos::Domain.by_prefix.delete( @prefix.to_s )
			end

			@prefix = self.qualify_domain_uri( uri )
			self.log.debug "Setting the prefix for %p to %p" % [ self, @prefix ]
			Rhizos::Domain.by_prefix[ @prefix.to_s ] = self
		end

		return @prefix
	end


	### Declare a node type for the domain with the given +name+ and +description+. If the `:is`
	### option is given, register an :IS_A REL for the type to the specified type.
	def self::type( name, description, is_a: nil, &block )
		source = if self.name&.match?( /\A[:\w+]\z/ )
				Object.const_source_location( self.name )
			else
				"(unknown)"
			end
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
			relation = self.relations[ name ]
			relation.description = description if description
			relation.instance_eval( &block ) if block

		in {from: Symbol, to: Symbol}
			self.log.debug "Adding a %p REL from %p to %p" % [ name, options[:from], options[:to] ]
			self.relations[ name ].add_connection( **options )

		else
			raise "Rel with options: %p not yet supported." % [ options ]
		end
	end
	singleton_method_alias :rel, :relation


	### Declare that an Evolver with the specified +name+ should be started for a Factspace
	### using this domain.
	def self::evolver( name, description=nil, **options )
		evolver_class = Rhizos::Evolver.get_subclass( name )
		self.evolvers[ name ] = evolver_class
	end


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
	### a query object that can be used to install them in a Ladybug database.
	def self::collate_schema( domains )
		domain_classes = domains.map( &:class )

		self.log.debug "Collating schema from domains: %p" % [ domain_classes ]
		type_chunks = self.collate_schema_types( domain_classes )
		rel_chunks = self.collate_schema_relations( domain_classes )
		schema_query = ( type_chunks + rel_chunks ).join( "\n\n" )

		self.log.debug "Schema is: \n---\n%s\n---\n" % [ schema_query ]
		return Rhizos.query( schema_query )
	end


	### Collate the types from the specified +domain_classes+ and return chunks of
	### Cypher source.
	def self::collate_schema_types( domain_classes )
		merged = {}

		domain_classes.each do |domain|
			self.log.debug "Collating types from: %p" % [ domain ]
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


	### Return a FFI::RadixTree::Tree of domain URIs suitable for lookup, building it
	### if necessary.
	def self::uri_trie
		return @uri_trie ||= self.build_uri_trie
	end


	### Return an FFI::RadixTree::Tree out of all loaded domains' prefix URIs.
	def self::build_uri_trie
		trie = FFI::RadixTree::Tree.new
		self.log.info "Building the domain URI trie for %d domains" %
			[ self.derivative_classes.size ]

		self.derivative_classes.each do |domain|
			uri = domain.prefix.to_s
			self.log.debug "  adding %p" % [ uri ]
			trie.push( uri, uri )
		end

		return trie
	end


	### Return the Domain class associated with the given +domain_uri+.
	def self::for_uri( domain_uri )
		domain_uri = self.qualify_domain_uri( domain_uri )
		self.log.debug "Looking up the domain URI for %p" % [ domain_uri ]
		prefix = Rhizos::Domain.uri_trie.longest_prefix_value( domain_uri.to_s )
		self.log.debug "  the prefix for %p is: %p" % [ domain_uri, prefix ]
		return Rhizos::Domain.by_prefix[ prefix ]
	end


	### Return the given +uri+ as a fully-qualified absolute URI object. Relative URIs will
	### have the DEFAULT_PREFIX_URI prepended.
	def self::qualify_domain_uri( uri )
		uri = URI( uri.to_s )
		uri = DEFAULT_PREFIX_URI + uri unless uri.absolute?

		return uri
	end


	### Collate all the types and relations from the specified +domains+ and return a
	### query object that can be used to remove them.
	def self::remove_schema( *domains )
		delete_query = %{MATCH (n) WHERE LABEL(n) <> "%s" DETACH DELETE n} % [ DOMAIN_INFO_TABLE ]
		return Rhizos.query( delete_query )
	end


	### Return the currently-loaded domains in topological (dependency) order.
	def self::sorted
		return self.tsort.reverse
	end


	### TSort API -- yield each model class.
	def self::tsort_each_node( &block )
		self.log.debug "TSort: yielding %d children" % [ self.derivative_classes.size ]
		self.derivative_classes.each( &block )
	end


	### TSort API -- yield each of the given +model_class+'s dependent model
	### classes.
	def self::tsort_each_child( model_class ) # :yields: model_class
		self.log.debug "TSort: yielding children of %p" % [ model_class ]
		Rhizos::Domain.derivative_classes.select do |domain|
			yield( domain ) if domain.dependencies.include?( model_class.prefix )
		end
	end


	### Reset the domain class's domain lookup data structures. This will cause them to be
	### rebuilt when they are next used.
	def self::reset_domain_lookup
		@uri_trie = nil
	end


	#
	# Instance methods
	#

	### Create a new instance of the Domain for the given +factspace+
	def initialize( factspace )
		@factspace = factspace
		@evolvers  = self.class.evolvers.values.each_with_object({}) do |evolver_class, hash|
			evolver = evolver_class.new( self )
			hash[ evolver.name ] = evolver
		end
	end


	######
	public
	######

	##
	# Instances of Rhizos::Evolvers declared by the domain.
	attr_reader :evolvers

	##
	# The Rhizos::Factspace this domain is loaded into
	attr_reader :factspace



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


	### Start any processes associated with the Domain.
	def start
		self.start_evolvers
	end


	### Stop any processes associated with the Domain.
	def stop
		self.stop_evolvers
	end


	#
	# Evolvers
	#

	### Get an evolver by its name. Returns `nil` if no such evolver is loaded.
	def get_evolver( name )
		return self.evolvers[ name.to_s ]
	end


	### Start the currently-loaded Evolvers.
	def start_evolvers
		self.log.info "Starting evolvers."
		self.evolvers.each do |name, evolver|
			self.log.info "  starting %s" % [ name ]
			evolver.start( self.factspace )
		end
	end


	### Stop all the currently-running evolvers.
	def stop_evolvers
		self.log.info "Stopping evolvers."
		self.evolvers.each do |name, evolver|
			self.log.info "  stopping %s" % [ name ]
			evolver.stop( self.factspace )
		end
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


