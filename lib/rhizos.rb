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

	# The name of the environment variable which can be used to set the config path
	CONFIG_ENV = 'RHIZOS_CONFIG'

	# The name of the config file for local overrides.
	LOCAL_CONFIG_FILE = Pathname( '~/.rhizos.yml' ).expand_path

	# The name of the config file that's loaded if none is specified.
	DEFAULT_CONFIG_FILE = Pathname( 'config.yml' ).expand_path


	# A temporary placeholder object used in place of the eventual monadic query
	# composer (library? class?)
	QueryPlaceholder = Struct.new( 'QueryPlaceholder', :cypher )


	# Loggability -- Set up a logger for Rhizos objects
	log_as :rhizos


	autoload :Constants, 'rhizos/constants'
	autoload :Factspace, 'rhizos/factspace'
	autoload :Domain, 'rhizos/domain'
	autoload :DomainType, 'rhizos/domain_type'
	autoload :DomainRelation, 'rhizos/domain_relation'
	autoload :DomainPropertyDSL, 'rhizos/domain_property_dsl'

	autoload :Error, 'rhizos/exceptions'
	autoload :DomainError, 'rhizos/exceptions'
	autoload :SchemaError, 'rhizos/exceptions'


	### Construct and return a Rhizos::Factspace using the specified arguments.
	def self::factspace( ... )
		return Rhizos::Factspace.new( ... )
	end


	#
	# Configuration API
	#

	### Get the loaded config (a Configurability::Config object)
	def self::config
		Configurability.loaded_config
	end


	### Returns +true+ if the configuration has been loaded at least once.
	def self::config_loaded?
		return self.config ? true : false
	end


	### Load the specified +config_file+, install the config in all objects with
	### Configurability, and call any callbacks registered via #after_configure.
	def self::load_config( config_file=nil, defaults=nil )
		config_file ||= ENV[ CONFIG_ENV ]
		config_file ||= LOCAL_CONFIG_FILE if LOCAL_CONFIG_FILE.exist?
		config_file ||= DEFAULT_CONFIG_FILE
		config_file = Pathname( config_file ) if config_file

		defaults ||= Configurability.gather_defaults

		config = if config_file&.exist? && ! config_file&.empty?
				self.log.info "Loading config from %p with defaults for sections: %p." %
					[ config_file, defaults.keys ]
				Configurability::Config.load( config_file, defaults )
			else
				Configurability.default_config
			end

		config.install
	end


	### Return the configuration defaults as a Configurability::Config object.
	def self::default_config
		return Configurability.default_config
	end


	### Return a Cypher query object made from the given +cypher_source+.
	def self::query( cypher_source )
		return QueryPlaceholder.new( cypher: cypher_source )
	end

end # module Rhizos

