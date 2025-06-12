# -*- ruby -*-

require 'set'
require 'securerandom'

require 'configurability'
require 'loggability'
require 'concurrent'
require 'mixins'

require 'rhizos' unless defined?( Rhizos )


class Rhizos::Factspace
	extend Loggability,
		Configurability,
		Mixins::MethodUtilities
	include Concurrent::Async,
		Rhizos::Constants


	# The default options to use when starting
	DEFAULT_OPTIONS = {
		domains: [],
		db_path: '',
	}.freeze


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
		raw = self.machine_id_file.read or return nil
		return nil if raw.empty?

		normalized = raw.gsub( /\A(\h{8})(\h{4})(\h{4})(\h{4})(\h{12})\z/, '\1-\2-\3-\4-\5' )
		return nil unless normalized.match?( UUID_PATTERN )

		return normalized
	end


	### Create a new Factspace for this host and start it. If the +block+ is given,
	### yield the instance to the block before it's started.
	def self::start( **options, &block )
		instance = new( **options )
		block.call( instance, **options ) if block
		instance.start

		return instance
	end



	### Create a new Factspace configured with the specified +options+.
	def initialize( **options )
		@options   = DEFAULT_OPTIONS.merge( **options ).freeze

		@node_id   = nil
		@conn      = nil
		@thread    = nil
		@domains   = nil

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
	# True if the factspace main thread will continue running.
	attr_predicate_accessor :running


	### Start up the Factspace. Returns the main thread of execution.
	def start
		@node_id = self.class.read_node_id or
			raise "couldn't read host's node ID file"

		self.log.info "Starting %s." % [ self.node_name ]

		@conn = self.connect_to_database
		@domains = self.load_domains

		self.create_local_actor
		self.start_evolvers

		@thread = Thread.new( &self.method(:start_handling_events) )
		return @thread
	end


	### Stop the Factspace if it's running.
	def stop
		if self.running?
			self.log.info "Stopping %s" % [ self.node_name ]
			self.running = false
			self.thread.join( 5 ) or self.thread.kill
		end
	end


	### Return the Factspace's node name, which is based on its UUID.
	def node_name
		return "factspace-%s" % [ self.node_id ]
	end


	### Load the domains the Factspace will use.
	def load_domains
		default_domains = self.load_default_domains
		user_domains = self.load_user_domains

		domains = default_domains + user_domains

		schema = Rhizos::Domain.collate_schema( domains )
		self.log.info "Installing the schema."
		self.conn.run( schema.cypher )

		return domains
	end


	### Load the domains that define the core functionality of the Factspace and
	### return them as a Set.
	def load_default_domains
		self.log.info "Loading the default domain."
		default_domain = Rhizos::Domain.create( :default )

		return Set.new([ default_domain ])
	end


	### Load any domains specified by the user in the `:domains` options passed to
	### the constructor and return them as a Set.
	def load_user_domains
		domain_names = Array( self.options[:domains] )
		return domain_names.each_with_object( Set.new ) do |domain_name, domains|
			self.log.info "Loading the `%s' domain." % [ domain_name ]
			domain = Rhizos::Domain.create( domain_name )
			domains.add( domain )
		end
	end


	### Create or update the local Actor that represents this factspace.
	def create_local_actor
		self.log.info "Creating local Actor node"
		stmt = self.conn.prepare( <<~END_OF_QUERY )
			MERGE (a:Actor {id: uuid($id), isLocal: true})-[i:IS_A]->(f:Fact {confidence: 100})
			ON MATCH SET f.updatedAt = current_timestamp()
			RETURN f.id
		END_OF_QUERY

		result = stmt.execute( id: self.node_id )
		self.log.debug "Result: %s" % [ result.to_s ]

		return result.to_a.first
	end


	### For each loaded domain, load all of its evolvers.
	def start_evolvers
		evolvers = self.domains.flat_map( &:evolvers )
		evolvers.each do |evolver|
			self.log.info "  starting %s" % [ evolver.name ]
			evolver.start( self )
		end
	end


	### Create the connetion to the Kuzu database
	def connect_to_database
		db_path = self.options[:db_path] or raise "No database path set in options."
		db = Kuzu.database( db_path ) or raise "Couldn't connect to `%s'" % [ db_path ]
		return db.connect
	end


	### Start evolving the Factspace with events.
	def start_handling_events
		Thread.current.abort_on_exception = true
		Thread.current.name = "Factspace event handler"
		start_time = Process.clock_gettime( Process::CLOCK_MONOTONIC )

		self.running = true

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
		return "%s [%p] (%srunning)" % [
			self.node_name,
			self.db,
			self.running? ? '' : 'not ',
		]
	end

end # class Rhizos::Factspace

