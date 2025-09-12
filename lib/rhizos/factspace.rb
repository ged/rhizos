# -*- ruby -*-

require 'set'
require 'fileutils'
require 'securerandom'

require 'configurability'
require 'loggability'
require 'concurrent'
require 'mixins'

require 'rhizos' unless defined?( Rhizos )
require 'rhizos/domain'
require 'rhizos/refinements'

using Rhizos::NumericRefinements


# The datastore interface for Facts in Rhizos.
#
# The Factspace is launched in three stages: instantiation, setup, and start.
#
# ## Instantiation
# 
# New instances are set up with two critical pieces of information: the path to
# the database file on disk, and the list of user domains to load. Both of these
# have reasonable defaults, so they're optional.
#
# The path of the database is straightforward, but if you set it to `nil`, an
# in-memory database will be used instead of a permanent one.
#
# The +domains+ can be set when the Factspace is constructed, or added to a new
# instance. Once the Factspace has had #setup called on it, the domains are
# immmutable.
#
# ## To Document
#
# - Querying
# - Evolvers
# - Actor
# - Timer API
#
class Rhizos::Factspace
	extend Loggability,
		Configurability,
		Mixins::MethodUtilities
	include Concurrent::Async,
		Rhizos::Constants,
		Mixins::Inspection

	# The default options to use when starting
	DEFAULT_OPTIONS = {}.freeze

	# The domains to always load
	DEFAULT_DOMAINS = %i[ default ]


	# Loggability API -- use the Rhizos logger
	log_to :rhizos


	# Configurability API -- declare settings for Factspace
	configurability( 'rhizos.factspace' ) do

		##
		# The persistent ID that identifies this Factspace's Actor
		setting :machine_id_file, default: '/etc/machine-id' do |value|
			Pathname( value )
		end

	end


	### Return the ID for this host, or +nil+ if one could not be read.
	def self::read_node_id
		raw = self.machine_id_file.read&.chomp&.downcase or return nil
		return nil if raw.empty?

		normalized = raw.gsub( /\A(\h{8})(\h{4})(\h{4})(\h{4})(\h{12})\z/, '\1-\2-\3-\4-\5' )
		return nil unless normalized.match?( UUID_PATTERN )

		return normalized
	rescue Errno::ENOENT => err
		raise err, "while reading the machine-id file"
	end


	### Create a new Factspace for this host and set it up, but don't start it. Returns
	### the new instance.
	def self::setup( db_path: nil, domains: [], **options )
		instance = new( db_path:, domains:, **options )
		instance.setup

		return instance
	end


	### Create a new Factspace for this host and start it. If the +block+ is given,
	### yield the instance to the block before it's started. Returns the new instance.
	def self::start( db_path: nil, domains: [], **options, &block )
		instance = self.setup( db_path:, domains:, **options, &block )
		block.call( instance, **options ) if block
		instance.start

		return instance
	end


	#
	# Instance methods
	#

	### Create a new Factspace configured with the specified +options+.
	def initialize( db_path: nil, domains: [], **options )
		@options   = DEFAULT_OPTIONS.merge( **options ).freeze

		@db_path   = db_path
		@domains   = self.load_domains( *domains )
		self.log.info "Loaded domains are now: %p" % [ self.domains ]

		@node_id   = nil
		@conn      = nil
		@thread    = nil
		@evolvers  = nil
		@actor     = nil
		@timers    = nil

		@running   = false
	end


	######
	public
	######

	##
	# The Hash of option the Factspace was created with
	attr_reader :options

	##
	# The Factspace's node id
	attr_reader :node_id

	##
	# The Kuzu::Connection object used to access the graph database
	attr_reader :conn

	##
	# The Factspace's main Thread
	attr_reader :thread

	##
	# The Set of Rhizos::Domains used by this Factspace
	attr_reader :domains

	##
	# The UUID (as a String) of this Factspace's Actor Fact
	attr_reader :actor

	##
	# The evolver (Rhizos::Evolver) instances started from the loaded domains
	attr_reader :evolvers

	##
	# a Set of registered periodic Rhizos::Timer objects.
	attr_reader :timers

	##
	# True if the factspace main thread will continue running.
	attr_predicate_accessor :running


	### Ensure the Factspace is set up for running.
	def setup
		self.log.info "Setting up the Factspace."
		self.domains.freeze

		# Or-equal so this method is idempotent
		@node_id  ||= self.class.read_node_id or
			raise "couldn't read host's node ID file"

		@conn     ||= self.connect_to_database
		self.check_or_install_schema

		@actor    ||= self.create_local_actor
		@evolvers ||= self.load_evolvers
		@timers   ||= Set.new
	end


	### Start up the Factspace. Returns the main thread of execution.
	def start
		self.setup
		self.start_evolvers
		self.start_timers
		self.running = true

		self.log.info "Starting %s." % [ self.node_name ]
		@thread = Thread.new( &self.method(:start_handling_events) )

		return @thread
	end


	### Stop the Factspace normally if it's running, cleaning up its database.
	def stop
		if self.running?
			self.log.info "Stopping %s" % [ self.node_name ]
			self.stop_timers
			self.stop_evolvers
			self.running = false
			self.thread.join( 5 ) or self.thread.kill
		else
			self.log.info "Already stopped."
		end
	end


	### Return the Factspace's node name, which is based on its UUID.
	def node_name
		return "factspace-%s" % [ self.node_id ]
	end


	### Create or update the local Actor that represents this factspace.
	def create_local_actor
		self.log.info "Creating local Actor node"
		actor_query = Rhizos.query( CREATE_LOCAL_ACTOR_QUERY )

		tuples = self.query( actor_query ) do |stmt|
			self.log.debug "Creating actor node %s" % [ self.node_id ]
			stmt.bind( id: self.node_id )
		end

		return tuples.first['f.id']
	end


	#
	# High-level query API
	#

	### The primary query interface: execute the specified +query_obj+ against the
	### database and return the resulting tuples. If a block is given, a Kuzu::PreparedStatement
	### is yielded to it before execution so that the block can bind variables to it.
	def query( query_obj )
		source = query_obj.cypher
		if block_given?
			statement = self.conn.prepare( source )
			yield( statement )
			return statement.execute {|res| res.tuples }
		else
			return self.conn.query( source ) {|res| res.tuples }
		end
	rescue Kuzu::QueryError => err
		self.log.error "%p in query `%s`: %s" % [ err.class, source, err.message ]
		raise
	end


	### Return a Kuzu::Node for each Fact in the Factspace.
	def facts
		query = Rhizos.query( MATCH_FACTS_QUERY )
		tuples = self.query( query )
		return tuples.map {|tuple| tuple['f'] }
	end


	### Return a Kuzu::Node for each Lifetime in the Factspace.
	def lifetimes
		query = Rhizos.query( MATCH_LIFETIMES_QUERY )
		tuples = self.query( query )
		return tuples.map {|tuple| tuple['l'] }
	end


	### Return a Kuzu::Node for each Actor in the Factspace.
	def actors
		query = Rhizos.query( MATCH_ACTORS_QUERY )
		tuples = self.query( query )
		return tuples.map {|tuple| tuple['a'] }
	end



	#
	# Timers
	#

	### Register a timer for callback execution at +interval+.
	### If the factspace is running, the callback is executed immediately.
	def add_periodic_timer( interval=60.seconds, &callback )
		timer = Rhizos::Timer.new( interval, &callback )

		self.timers.add( timer )
		timer.start( fire_now: true ) if self.running?

		return timer
	end


	### Un-register the specified +timer+ and cancel it.
	def cancel_periodic_timer( timer )
		raise "unknown timer %p" % [ timer ] unless self.timers.include?( timer )

		self.timers.delete( timer )
		timer.stop
	end


	### Cancel running periodic timers.
	def stop_timers
		self.log.info "Stopping %d periodic timers." % [ self.timers.size ]
		self.timers.each( &:stop )
	end


	### Begin all registered periodic timers.
	def start_timers
		self.log.info "Starting %d periodic timers." % [ self.timers.size ]
		self.timers.each( &:start )
	end


	#
	# Domains
	#

	### Load the domains the Factspace will use.
	def load_domains( *domains )
		default_domains = self.load_default_domains
		user_domains = self.load_user_domains( *domains )

		return default_domains + user_domains
	end


	### Load additional domains into the Factspace. This raises if called after the
	### Facespace is started.
	def add_domains( *new_domains )
		raise "can't add domains to a running Factspace" if self.running?

		new_domains = self.load_user_domains( *new_domains )
		self.domains.merge( new_domains )
	end


	### Sanity-check the schema of the current database against the list of +domains+. If
	### any are missing from the database, missing from the listed +domains+, or have
	### mismatched versions, raises an error.
	def check_schema( domains )
		domain_info = Rhizos::Domain.schema_info_hash( self )

		self.check_schema_tables( domains, domain_info )
		self.check_schema_versions( domains, domain_info )
	end


	### Compare the specified +domains+ with the +domain_info+ of an existing database
	### and raise an error if they indicate that different domains are loaded.
	def check_schema_tables( domains, domain_info )
		installed_domains = domain_info.keys.to_set
		loaded_domains = domains.map( &:name ).to_set

		if installed_domains.proper_subset?( loaded_domains )
			missing = loaded_domains - installed_domains
			raise Rhizos::SchemaError,
				"existing database is missing schema for some domains: %s" % [ missing.to_a ]

		elsif loaded_domains.proper_subset?( installed_domains )
			extra = installed_domains - loaded_domains
			raise Rhizos::SchemaError,
				"existing database has domains that are not loaded: %s" % [ extra.to_a ]
		end
	end


	### Compare the versions of the specified +domains+ with the +domain_info+ of an
	### existing database and raise an error if they indicate that they have incompatible
	### versions.
	def check_schema_versions( domains, domain_info )
		incompatible = []

		domains.each do |domain|
			previous_version = domain_info[ domain.name ]

			# Semver-checking?
			unless domain.version == previous_version
				incompatible << "  %s: %s vs. %s" %
					[ domain.name, previous_version, domain.version ]
			end
		end

		unless incompatible.empty?
			raise Rhizos::SchemaError,
				"existing database has incompatible versions: %s\n" % [ incompatible.join("\n  ") ]
		end
	end


	### Install the schema for the specified +domains+ (an Array of Rhizos::Domain objects)
	def install_schema( domains )
		self.log.info "Installing the schema in domains: %p." % [ domains ]
		self.conn.run( DOMAIN_INFO_TABLE_SCHEMA )

		create_stmt = self.conn.prepare( ADD_DOMAIN_INFO_QUERY )
		domains.each do |domain|
			self.log.info "Installing the %p domain at version %p" % [ domain.name, domain.version ]
			create_stmt.execute!( name: domain.name, version: domain.version )
		end

		query = Rhizos::Domain.collate_schema( domains )
		self.conn.run( query.cypher )
	end


	### Remove the data from all the loaded domains.
	def unload_domains
		query = Rhizos::Domain.remove_schema( self.domains )
		self.conn.run( query.cypher )

		return true
	end


	### Load the domains that define the core functionality of the Factspace and
	### return them as a Set.
	def load_default_domains
		self.log.info "Loading the default domains."

		return DEFAULT_DOMAINS.map do |domain_name|
			Rhizos::Domain.create( domain_name )
		end.to_set
	end


	### Load any domains specified by the user in the `:domains` options passed to
	### the constructor and return them as a Set.
	def load_user_domains( *domains )
		domain_names = Array( domains ).flatten

		# :TODO: Load dependency domains too

		return domain_names.map do |domain_name|
			self.log.info "Loading the `%s' domain." % [ domain_name ]
			Rhizos::Domain.create( domain_name )
		end.to_set
	end



	#
	# Evolvers
	#

	### Get an evolver by its name. Returns `nil` if no such evolver is loaded.
	def get_evolver( name )
		return self.evolvers[ name.to_s ]
	end


	### For each loaded domain, load all of its evolvers.
	def load_evolvers
		self.log.info "Loading evolvers from %d domains." % [ self.domains.size ]
		return self.domains.each_with_object( {} ) do |domain, hash|
			domain.evolvers.each do |evolver|
				name = evolver.name
				self.log.info "  loaded the %p evolver from the %s domain" % [ name, domain ]
				hash[ name ] = evolver
			end
		end
	end


	### Start the currently-loaded Evolvers.
	def start_evolvers
		self.log.info "Starting evolvers."
		self.evolvers.each do |name, evolver|
			self.log.info "  starting %s" % [ name ]
			evolver.start( self )
		end
	end


	### Stop all the currently-running evolvers.
	def stop_evolvers
		self.log.info "Stopping evolvers."
		self.evolvers.each do |name, evolver|
			self.log.info "  stopping %s" % [ name ]
			evolver.stop( self )
		end
	end


	### Return the path to the database as a Pathname, or `nil` if it's an in-memory
	### database.
	def db_path
		return nil if @db_path.nil? || @db_path == ''

		return Pathname( @db_path ).expand_path
	end


	### Create the connetion to the Kuzu database
	def connect_to_database
		db = Kuzu.database( self.db_path ) or
			raise "Couldn't create database: %s" % [ self.db_path || '(in-memory db)' ]

		return db.connect
	end


	### Ensure the current database has the correct schema installed.
	def check_or_install_schema
		if Rhizos::Domain.schema_is_installed?( self )
			self.check_schema( self.domains )
		else
			self.install_schema( self.domains )
		end
	end


	### Start evolving the Factspace with events.
	def start_handling_events
		Thread.current.abort_on_exception = true
		Thread.current.name = "Factspace event handler"
		start_time = Process.clock_gettime( Process::CLOCK_MONOTONIC )

		self.log.info "Started handling events."
		while self.running?
			# :TODO:
			sleep 0.5 # for now
		end
		self.log.info "Done handling events."

		return Process.clock_gettime( Process::CLOCK_MONOTONIC ) - start_time
	end


	### Inspection mixin API -- provide the details for a string represnetation
	### of the object suitable for human debugging.
	def inspect_details
		if self.running?
			return "%s [%p] (running)" % [
				self.node_name,
				self.conn,
			]
		else
			return "(not running)"
		end
	end



end # class Rhizos::Factspace

